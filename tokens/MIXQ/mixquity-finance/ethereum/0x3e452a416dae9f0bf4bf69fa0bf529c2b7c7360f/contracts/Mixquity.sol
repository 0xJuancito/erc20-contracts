pragma solidity 0.8.21;

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint8 _tokenDecimals
    ) {
        _name = _tokenName;
        _symbol = _tokenSymbol;
        _decimals = _tokenDecimals;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

import "./Tracker.sol";

// Website  : https://mixquity.finance/
// X        : https://twitter.com/Mixquity
// Telegram : https://t.me/mixquity
// Linktree : https://linktr.ee/mixquity
// Medium   : https://medium.com/@mixquity

///////////////////////////////////////////////////////////
//    _____  .__       ________        .__  __           //
//   /     \ |__|__  __\_____  \  __ __|__|/  |_ ___.__. //
//  /  \ /  \|  \  \/  //  / \  \|  |  \  \   __<   |  | //
// /    Y    \  |>    </   \_/.  \  |  /  ||  |  \___  | //
// \____|__  /__/__/\_ \_____\ \_/____/|__||__|  / ____| //
//         \/         \/      \__>               \/      //
///////////////////////////////////////////////////////////

contract MixQuity is ERC20Detailed, Ownable {
    struct Taxes {
        uint256 marketing;
        uint256 lpReward;
    }

    uint8 private constant DECIMALS = 9;
    uint256 private constant INITIAL_TOKENS_SUPPLY =
        10_000_000 * 10 ** DECIMALS;

    uint256 private constant TOTAL_PARTS =
        type(uint256).max - (type(uint256).max % INITIAL_TOKENS_SUPPLY);

    Tracker public tracker;
    uint256 public compoundFrequency = 1800; // Auto-rebase every 30 minutes
    uint256 public nextCompound;
    uint256 public lastCompound;
    uint256 public compoundEnd;
    uint256 public finalEpoch = 960; // Rebase complete after 20 days
    uint256 public currentEpoch;
    uint256 public compoundPercentage = 480857656; // The Rebase Rate is set at 0.480857656%
    bool public autoCompound;

    address public marketingWallet;

    Taxes public phase1 = Taxes(300, 300); // Day [1 - 20]: Buy Tax = Sell Tax = 6%
    Taxes public phase2 = Taxes(100, 300); // Day [20 - ∞]: Buy Tax = Sell Tax = 4%

    Taxes public curFee = phase1;
    uint256 public curTotalTax = phase1.marketing + phase1.lpReward;
    uint256 public antiBotFee = 9000; // Sniper-bot transactions will be charged 90% tax

    uint256 antiBotTime;
    uint256 antiBuySellBotTime;
    uint256 blockBotTime;
    uint256 antiBotDuration = 24; // Bots will be automatically blocked in this duration
    uint256 blockBotDuration = 300; // Bots will be manually blocked in this duration
    uint256 antiBotBuySellDuration = 600;
    uint256 maxBuyAntiBotAmount = 300_000 * 10 ** DECIMALS;

    event SendDividends(uint256 tokensSwapped, uint256 amount);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event Compound(uint256 indexed time, uint256 totalSupply);

    IUniswapRouter public router;
    address public pair;

    bool public tradingEnable = false;

    uint256 private _totalSupply;
    uint256 private _partsPerToken;

    uint256 private swapTokenAtAmount = INITIAL_TOKENS_SUPPLY / 200; // Users will get LP rewards when tax hits 0.5% initial supply

    mapping(address => uint256) private _partBalances;
    mapping(address => mapping(address => uint256)) private _allowedTokens;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => mapping(uint256 => bool)) public isTransferSpent;
    mapping(address => bool) public blockedBot;

    bool inSwap;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _router,
        address _marketing
    ) ERC20Detailed("MixQuity.finance", "MIXQ", DECIMALS) {
        tracker = new Tracker();

        marketingWallet = _marketing;
        router = IUniswapRouter(_router);

        _totalSupply = INITIAL_TOKENS_SUPPLY;
        _partBalances[msg.sender] = TOTAL_PARTS;
        _partsPerToken = TOTAL_PARTS / (_totalSupply);

        pair = IFactory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        excludedFromFees(address(this), true);
        excludedFromFees(address(router), true);
        excludedFromFees(msg.sender, true);
        excludedFromFees(_marketing, true);

        tracker.updateRewardToken(address(pair));

        tracker.excludeFromDividends(address(tracker), true);
        tracker.excludeFromDividends(address(this), true);
        tracker.excludeFromDividends(msg.sender, true);
        tracker.excludeFromDividends(address(0), true);
        tracker.excludeFromDividends(_marketing, true);
        tracker.excludeFromDividends(_router, true);
        tracker.excludeFromDividends(address(pair), true);

        _allowedTokens[address(this)][address(router)] = type(uint256).max;
        _allowedTokens[address(msg.sender)][address(router)] = type(uint256)
            .max;

        emit Transfer(
            address(0),
            address(msg.sender),
            balanceOf(address(this))
        );
    }

    function claim() external {
        tracker.processAccount(payable(msg.sender));
    }

    function trackerRescueETH20Tokens(address tokenAddress) external onlyOwner {
        tracker.trackerRescueETH20Tokens(msg.sender, tokenAddress);
    }

    function excludeFromDividends(
        address account,
        bool value
    ) public onlyOwner {
        tracker.excludeFromDividends(account, value);
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return tracker.totalDividendsDistributed();
    }

    function withdrawableDividendOf(
        address account
    ) public view returns (uint256) {
        return tracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(
        address account
    ) public view returns (uint256) {
        return tracker.balanceOf(account);
    }

    function getAccountInfo(
        address account
    ) external view returns (address, uint256, uint256, uint256, uint256) {
        return tracker.getAccount(account);
    }

    function manualLiquidityDistribution(uint256 amount) public onlyOwner {
        bool success = IERC20(pair).transferFrom(
            msg.sender,
            address(tracker),
            amount
        );
        if (success) {
            tracker.distributeRewardTokenDividends(amount);
        }
    }

    function forceSend() external onlyOwner {
        uint256 ETHbalance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: ETHbalance}("");
        require(success);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address owner_,
        address spender
    ) external view override returns (uint256) {
        return _allowedTokens[owner_][spender];
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _partBalances[who] / (_partsPerToken);
    }

    function shouldCompound() public view returns (bool) {
        return
            currentEpoch < finalEpoch &&
            nextCompound > 0 &&
            nextCompound <= block.timestamp &&
            autoCompound;
    }

    function lpSync() internal {
        IPair _pair = IPair(pair);
        _pair.sync();
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function excludedFromFees(address _address, bool _value) public onlyOwner {
        isExcludedFromFees[_address] = _value;
        emit ExcludeFromFees(_address, _value);
    }

    function blockBot(address[] calldata _addresses) external onlyOwner {
        require(
            block.timestamp <= blockBotTime || !tradingEnable,
            "Can only block bot in the first 5 minutes"
        );
        for (uint256 i = 0; i < _addresses.length; i++) {
            blockedBot[_addresses[i]] = true;
        }
    }

    function unblockBot(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            blockedBot[_addresses[i]] = false;
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(!blockedBot[sender] && !blockedBot[recipient], "You are bot");

        address pairAddress = pair;

        // prevent bot sandwich
        if (tx.origin == sender || tx.origin == recipient) {
            require(!isTransferSpent[tx.origin][block.number], "You are bot!");
            isTransferSpent[tx.origin][block.number] = true;
            if (antiBuySellBotTime > block.timestamp) {
                isTransferSpent[tx.origin][block.number + 1] = true;
            }
        }

        if (
            !inSwap &&
            !isExcludedFromFees[sender] &&
            !isExcludedFromFees[recipient]
        ) {
            uint256 totalFeePercentage;
            if (sender == pairAddress || recipient == pairAddress) {
                totalFeePercentage = curTotalTax;
            }

            require(tradingEnable, "Trading not live");
            if (antiBotTime >= block.timestamp) {
                if (sender == pairAddress) {
                    if (amount >= maxBuyAntiBotAmount) {
                        totalFeePercentage = antiBotFee;
                    }
                }
            }

            if (recipient == pairAddress) {
                if (balanceOf(address(this)) >= swapTokenAtAmount) {
                    swapAndLiquify(swapTokenAtAmount);
                }
            }

            if (shouldCompound() && sender != pairAddress) {
                _compound();
            }

            uint256 taxAmount;
            taxAmount = (amount * totalFeePercentage) / 10000;

            if (taxAmount > 0) {
                _partBalances[sender] -= (taxAmount * _partsPerToken);
                _partBalances[address(this)] += (taxAmount * _partsPerToken);

                emit Transfer(sender, address(this), taxAmount);
                amount -= taxAmount;
            }
        }

        _partBalances[sender] -= (amount * _partsPerToken);
        _partBalances[recipient] += (amount * _partsPerToken);

        try
            tracker.setBalance(sender, _partBalances[sender] / 10 ** 53)
        {} catch {}
        try
            tracker.setBalance(recipient, _partBalances[recipient] / 10 ** 53)
        {} catch {}

        emit Transfer(sender, recipient, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        if (_allowedTokens[from][msg.sender] != type(uint256).max) {
            require(
                _allowedTokens[from][msg.sender] >= value,
                "Insufficient Allowance"
            );
            _allowedTokens[from][msg.sender] =
                _allowedTokens[from][msg.sender] -
                (value);
        }
        _transfer(from, to, value);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 oldValue = _allowedTokens[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedTokens[msg.sender][spender] = 0;
        } else {
            _allowedTokens[msg.sender][spender] = oldValue - (subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedTokens[msg.sender][spender]);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        _allowedTokens[msg.sender][spender] =
            _allowedTokens[msg.sender][spender] +
            (addedValue);
        emit Approval(msg.sender, spender, _allowedTokens[msg.sender][spender]);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        _allowedTokens[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function _compound() internal returns (uint256) {
        uint256 cacheLastCompound = lastCompound;
        uint256 cacheCompoundFrequency = compoundFrequency;
        uint256 cacheFinalEpoch = finalEpoch;
        uint256 cacheCompoundEnd = compoundEnd;
        uint256 cacheTotalSupply = _totalSupply;
        uint256 cacheCompoundPercentage = compoundPercentage;
        uint256 compoundTime = block.timestamp;
        if (compoundTime > cacheCompoundEnd) {
            compoundTime = cacheCompoundEnd;
        }

        uint256 times = (compoundTime - cacheLastCompound) /
            cacheCompoundFrequency;

        lastCompound = cacheLastCompound + times * cacheCompoundFrequency;
        nextCompound = cacheLastCompound + cacheCompoundFrequency * (times + 1);

        if (times + currentEpoch > cacheFinalEpoch) {
            times = cacheFinalEpoch - currentEpoch;
        }

        currentEpoch += times;

        for (uint256 i = 0; i < times; i++) {
            cacheTotalSupply =
                (cacheTotalSupply * (10 ** 11 + cacheCompoundPercentage)) /
                10 ** 11;
        }

        if (cacheTotalSupply == _totalSupply) {
            emit Compound(compoundTime, cacheTotalSupply);
            return cacheTotalSupply;
        }

        _totalSupply = cacheTotalSupply;

        _partsPerToken = TOTAL_PARTS / (cacheTotalSupply);

        if (currentEpoch >= cacheFinalEpoch) {
            autoCompound = false;
            nextCompound = 0;
            curFee = phase2;
            curTotalTax = phase2.marketing + phase2.lpReward;
        }

        lpSync();

        emit Compound(compoundTime, cacheTotalSupply);

        return cacheTotalSupply;
    }

    function manualCompound() external {
        require(shouldCompound(), "Not time yet");
        _compound();
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnable, "Trading Live Already");
        _startCompound();
        tradingEnable = true;
        antiBotTime = block.timestamp + antiBotDuration;
        antiBuySellBotTime = block.timestamp + antiBotBuySellDuration;
        blockBotTime = block.timestamp + blockBotDuration;
    }

    function _startCompound() internal {
        require(currentEpoch == 0 && !autoCompound, "already started");
        autoCompound = true;
        nextCompound = block.timestamp + compoundFrequency;
        lastCompound = block.timestamp;
        compoundEnd = block.timestamp + finalEpoch * compoundFrequency;
    }

    function swapAndLiquify(uint256 tokens) private swapping {
        Taxes memory tempCurFee = curFee;
        uint256 tempCurTotalTax = curTotalTax;
        uint256 amountToSwap = (tokens * tempCurFee.marketing) /
            tempCurTotalTax;
        uint256 amountToLpReward = (tokens * tempCurFee.lpReward) /
            tempCurTotalTax;

        _swapAndAddliquidity(amountToLpReward);

        _swapTokensForETH(amountToSwap);

        uint256 ethTomarketing = address(this).balance;

        if (ethTomarketing > 0) {
            (bool success, ) = payable(marketingWallet).call{
                value: ethTomarketing
            }("");
            require(success, "Failed to send ETH to marketing wallet");
        }

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        if (lpBalance > 0) {
            bool success = IERC20(pair).transfer(address(tracker), lpBalance);
            if (success) {
                tracker.distributeRewardTokenDividends(lpBalance);
                emit SendDividends(tokens, lpBalance);
            }
        }
    }

    function _swapTokensForETH(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _swapAndAddliquidity(uint256 amount) internal {
        if (amount > 0) {
            uint256 half = amount / 2;
            uint256 otherHalf = amount - half;

            uint256 initialBalance = address(this).balance;

            _swapTokensForETH(half);

            uint256 newBalance = address(this).balance - (initialBalance);

            router.addLiquidityETH{value: newBalance}(
                address(this),
                otherHalf,
                0,
                0,
                address(this),
                block.timestamp
            );
        }
    }

    function setSwapAtAmount(uint256 _amount) external onlyOwner {
        swapTokenAtAmount = _amount;
    }

    function fetchBalances(address[] memory wallets) external {
        address wallet;
        for (uint256 i = 0; i < wallets.length; i++) {
            wallet = wallets[i];
            emit Transfer(wallet, wallet, 0);
        }
    }

    receive() external payable {}
}
