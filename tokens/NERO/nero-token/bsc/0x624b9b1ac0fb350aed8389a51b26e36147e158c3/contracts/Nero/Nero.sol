// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./DividendPayingToken.sol";
import "./IterableMapping.sol";
import "./Ownable.sol";
import "./IDex.sol";

library Address {
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }
}

contract Nero is ERC20, Ownable {
    using Address for address payable;

    IRouter public router;
    address public pair;

    bool private swapping;
    bool public swapEnabled = true;
    bool public tradingEnabled;
    uint256 public startTradingBlock;

    NeroDividendTracker public dividendTracker;

    address public constant deadWallet =
        0x000000000000000000000000000000000000dEaD;
    address public marketingWallet = 0x1aEd3C03Fbf136dF5bD5aFB66c6ecaD9A655961c;
    address public devWallet = 0x04d031ECa639fb7B40C830faB45471a19E7cA0C7;

    uint256 public swapTokensAtAmount = 1e5 * 10 ** 9;

    string private currentRewardToken;

    struct Taxes {
        uint256 rewards;
        uint256 marketing;
        uint256 liquidity;
        uint256 burn;
        uint256 dev;
    }

    Taxes public buyTaxes = Taxes(1, 3, 2, 3, 0);
    Taxes public sellTaxes = Taxes(1, 3, 2, 3, 0);

    uint256 public gasForProcessing = 300000;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );
    event SendDividends(uint256 tokensSwapped, uint256 amount);
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("Nero Token", "NERO") {
        transferOwnership(devWallet);
        dividendTracker = new NeroDividendTracker();

        IRouter _router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _pair = IFactory(_router.factory()).createPair(
            address(this),
            _router.WETH()
        );

        router = _router;
        pair = _pair;

        _setAutomatedMarketMakerPair(_pair, true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker), true);
        dividendTracker.excludeFromDividends(address(this), true);
        dividendTracker.excludeFromDividends(deadWallet, true);
        dividendTracker.excludeFromDividends(address(_router), true);

        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[marketingWallet] = true;
        _isExcludedFromFees[deadWallet] = true;
        _isExcludedFromFees[address(this)] = true;

        _tokengeneration(owner(), 1_000_000_000 * (10 ** 9));
    }

    receive() external payable {}

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function setBuyTaxes(
        uint256 _rewards,
        uint256 _marketing,
        uint256 _liquidity,
        uint256 _burnTax,
        uint256 _dev
    ) external onlyOwner {
        require(
            _rewards + _marketing + _liquidity + _burnTax + _dev <= 12,
            "Taxes cannot be more than 12%"
        );
        buyTaxes = Taxes(_rewards, _marketing, _liquidity, _burnTax, _dev);
    }

    function setSellTaxes(
        uint256 _rewards,
        uint256 _marketing,
        uint256 _liquidity,
        uint256 _burnTax,
        uint256 _dev
    ) external onlyOwner {
        require(
            _rewards + _marketing + _liquidity + _burnTax + _dev <= 12,
            "Taxes cannot be more than 12%"
        );
        sellTaxes = Taxes(_rewards, _marketing, _liquidity, _burnTax, _dev);
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).transfer(
            msg.sender,
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }

    function withdrawETH() external onlyOwner {
        uint256 BNBbalance = address(this).balance;
        payable(owner()).sendValue(BNBbalance);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "Nero: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function excludeFromDividends(
        address account,
        bool value
    ) external onlyOwner {
        dividendTracker.excludeFromDividends(account, value);
    }

    function setMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        marketingWallet = newWallet;
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(
            amount > totalSupply() / 1_000_000,
            "cant set swap threshold to less than 1/1000000 of total supply"
        );
        swapTokensAtAmount = amount;
    }

    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function setMinBalanceForDividends(uint256 amount) external onlyOwner {
        dividendTracker.setMinBalanceForDividends(amount);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(
            automatedMarketMakerPairs[newPair] != value,
            "Nero: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[newPair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(newPair, true);
        }

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    function setGasForProcessing(uint256 newValue) external onlyOwner {
        require(
            newValue >= 200000 && newValue <= 500000,
            "Nero: gasForProcessing must be between 200,000 and 500,000"
        );
        require(
            newValue != gasForProcessing,
            "Nero: Cannot update gasForProcessing to same value"
        );
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function setClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(
        address account
    ) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function getCurrentRewardToken() external view returns (string memory) {
        return dividendTracker.getCurrentRewardToken();
    }

    function dividendTokenBalanceOf(
        address account
    ) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getAccountDividendsInfo(
        address account
    )
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(
        uint256 index
    )
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getAccountAtIndex(index);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Nero: transfer from the zero address");
        require(to != address(0), "Nero: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount &&
            contractTokenBalance > 0;

        uint256 swapTax = sellTaxes.rewards +
            sellTaxes.marketing +
            sellTaxes.liquidity +
            sellTaxes.dev;

        if (
            canSwap &&
            !swapping &&
            swapEnabled &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;

            if (swapTax > 0) {
                swapAndLiquify(swapTokensAtAmount, swapTax);
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 swapAmt;
            uint256 burnAmt;
            if (automatedMarketMakerPairs[to]) {
                swapAmt = (amount * swapTax) / 100;
                burnAmt = (amount * sellTaxes.burn) / 100;
            } else if (automatedMarketMakerPairs[from]) {
                swapAmt =
                    (amount *
                        (buyTaxes.rewards +
                            buyTaxes.marketing +
                            buyTaxes.liquidity +
                            buyTaxes.dev)) /
                    100;
                burnAmt = (amount * buyTaxes.burn) / 100;
            }
            if (swapAmt > 0) {
                amount = amount - (swapAmt);
                super._transfer(from, address(this), swapAmt);
            }
            if (burnAmt > 0) {
                amount = amount - (burnAmt);
                super._transfer(from, address(deadWallet), burnAmt);
            }
        }
        super._transfer(from, to, amount);

        try dividendTracker.setBalance(from, balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(to, balanceOf(to)) {} catch {}

        if (!swapping) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }

    function swapAndLiquify(uint256 tokens, uint256 swapTax) private {
        uint256 denominator = swapTax * 2;
        uint256 tokensToAddLiquidityWith = (tokens * sellTaxes.liquidity) /
            denominator;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(toSwap);

        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance = deltaBalance /
            (denominator - sellTaxes.liquidity);
        uint256 bnbToAddLiquidityWith = unitBalance * sellTaxes.liquidity;

        if (bnbToAddLiquidityWith > 0) {
            // Add liquidity to pancake
            addLiquidity(tokensToAddLiquidityWith, bnbToAddLiquidityWith);
        }

        // Send BNB to marketingWallet
        uint256 marketingWalletAmt = unitBalance * 2 * sellTaxes.marketing;
        if (marketingWalletAmt > 0) {
            payable(marketingWallet).sendValue(marketingWalletAmt);
        }

        // Send BNB to dev wallet
        uint256 devWalletAmt = unitBalance * 2 * sellTaxes.dev;
        if (devWalletAmt > 0) {
            payable(devWallet).sendValue(devWalletAmt);
        }

        // Send BNB to rewardsContract
        uint256 dividends = unitBalance * 2 * sellTaxes.rewards;
        if (dividends > 0) {
            (bool success, ) = address(dividendTracker).call{value: dividends}(
                ""
            );
            if (success) emit SendDividends(tokens, dividends);
        }
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadWallet,
            block.timestamp
        );
    }
}

contract NeroDividendTracker is Ownable, DividendPayingToken {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping(address => bool) public excludedFromDividends;

    mapping(address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account, bool value);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(
        address indexed account,
        uint256 amount,
        bool indexed automatic
    );

    constructor()
        DividendPayingToken("Nero_Dividend_Tracker", "Nero_Dividend_Tracker")
    {
        claimWait = 3600;
        minimumTokenBalanceForDividends = 1 * (10 ** decimals());
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "Nero_Dividend_Tracker: No transfers allowed");
    }

    function setMinBalanceForDividends(uint256 amount) external onlyOwner {
        minimumTokenBalanceForDividends = amount * 10 ** decimals();
    }

    function excludeFromDividends(
        address account,
        bool value
    ) external onlyOwner {
        require(excludedFromDividends[account] != value);
        excludedFromDividends[account] = value;
        if (value == true) {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        } else {
            _setBalance(account, balanceOf(account));
            tokenHoldersMap.set(account, balanceOf(account));
        }
        emit ExcludeFromDividends(account, value);
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(
            newClaimWait >= 3600 && newClaimWait <= 86400,
            "Nero_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours"
        );
        require(
            newClaimWait != claimWait,
            "Nero_Dividend_Tracker: Cannot update claimWait to same value"
        );
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns (uint256) {
        return tokenHoldersMap.keys.length;
    }

    function getCurrentRewardToken() external view returns (string memory) {
        return IERC20Metadata(rewardToken).name();
    }

    function getAccount(
        address _account
    )
        public
        view
        returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable
        )
    {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if (index >= 0) {
            if (uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(
                    int256(lastProcessedIndex)
                );
            } else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length >
                    lastProcessedIndex
                    ? tokenHoldersMap.keys.length.sub(lastProcessedIndex)
                    : 0;

                iterationsUntilProcessed =
                    index +
                    (int256(processesUntilEndOfArray));
            }
        }

        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ? lastClaimTime + (claimWait) : 0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp
            ? nextClaimTime.sub(block.timestamp)
            : 0;
    }

    function getAccountAtIndex(
        uint256 index
    )
        public
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (index >= tokenHoldersMap.size()) {
            return (
                0x0000000000000000000000000000000000000000,
                -1,
                -1,
                0,
                0,
                0,
                0,
                0
            );
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if (lastClaimTime > block.timestamp) {
            return false;
        }

        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address account, uint256 newBalance) public onlyOwner {
        if (excludedFromDividends[account]) {
            return;
        }

        if (newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
            tokenHoldersMap.set(account, newBalance);
        } else {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }

        processAccount(payable(account), true);
    }

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if (numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 gasUsed = 0;

        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while (gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if (_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if (canAutoClaim(lastClaimTimes[account])) {
                if (processAccount(payable(account), true)) {
                    claims++;
                }
            }

            iterations++;

            uint256 newGasLeft = gasleft();

            if (gasLeft > newGasLeft) {
                gasUsed = gasUsed + (gasLeft.sub(newGasLeft));
            }

            gasLeft = newGasLeft;
        }

        lastProcessedIndex = _lastProcessedIndex;

        return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(
        address payable account,
        bool automatic
    ) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

        if (amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
            return true;
        }

        return false;
    }
}
