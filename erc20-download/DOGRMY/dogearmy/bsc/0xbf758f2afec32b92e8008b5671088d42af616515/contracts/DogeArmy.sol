// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./libraries/DividendTracker.sol";

contract DogeArmy is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    uint8 private constant _decimals = 9;

    bool private swapping;

    DividendTracker public dividendTracker;

    address public marketingWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    // sells have a higher fee
    uint256 public sellFeeIncreaseFactor = 100;

    uint256 public tradingActiveBlock = 0; // 0 means trading is not active
    mapping(address => bool) public boughtEarly; // mapping to track addresses that buy within the first 10 blocks pay a 3x tax for 24 hours to sell
    uint256 public earlyBuyPenaltyEnd; // determines when snipers/bots can sell without extra penalty

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled = true;

    address public presaleAddress;
    address public presaleRouterAddress;

    uint256 public totalFees;
    uint256 public rewardsFee;
    uint256 public marketingFee;
    uint256 public liquidityFee;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    /******************/

    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;

    // disable swap and processing for some addresses
    mapping(address => bool) private _isExcludedFromProcessing;

    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event ExcludedMaxTransactionAmount(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event marketingWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event BuybackMultiplierActive(uint256 duration);
    event BoughtEarly(address indexed sniper);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event SendDividends(uint256 tokensSwapped, uint256 amount);
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor(
        address _router,
        address _rewardToken,
        address _marketing,
        address _owner
    ) ERC20("DogeArmy", "DOGRMY") {
        uint256 _rewardsFee = 7;
        uint256 _marketingFee = 2;
        uint256 _liquidityFee = 1;

        uint256 totalSupply = 100 * 1e12 * 1e9;

        maxTransactionAmount = (totalSupply * 1) / 100; // 1% maxTransactionAmountTxn
        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05% swap tokens amount
        maxWallet = (totalSupply * 2) / 100; // 2% Max wallet

        rewardsFee = _rewardsFee;
        marketingFee = _marketingFee;
        liquidityFee = _liquidityFee;
        totalFees = rewardsFee + marketingFee + liquidityFee;

        dividendTracker = new DividendTracker(_router, _rewardToken);

        marketingWallet = _marketing; // set as marketing wallet

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);

        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(_owner);
        dividendTracker.excludeFromDividends(address(_uniswapV2Router));
        dividendTracker.excludeFromDividends(address(0xdead));

        // exclude from paying fees or having max transaction amount
        excludeFromFees(_owner, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        excludeFromMaxTransaction(_owner, true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(dividendTracker), true);
        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        excludeFromMaxTransaction(address(0xdead), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(_owner), totalSupply);
        transferOwnership(_owner);
    }

    receive() external payable {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // only use if conducting a presale (more specifically on DxSale where there is both an address and a router)
    function addPresaleAddressForExclusions(address _presaleAddress, address _presaleRouterAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        excludeFromFees(_presaleAddress, true);
        dividendTracker.excludeFromDividends(_presaleAddress);
        excludeFromMaxTransaction(_presaleAddress, true);
        presaleRouterAddress = _presaleRouterAddress;
        excludeFromFees(_presaleRouterAddress, true);
        dividendTracker.excludeFromDividends(_presaleRouterAddress);
        excludeFromMaxTransaction(_presaleRouterAddress, true);
    }

    function emergencyPresaleAddressUpdate(address _presaleAddress, address _presaleRouterAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        presaleRouterAddress = _presaleRouterAddress;
    }

    // disable Transfer delay - cannot be reenabled
    function disableTransferDelay() external onlyOwner returns (bool) {
        transferDelayEnabled = false;
        return true;
    }

    // excludes wallets and contracts from dividends (such as CEX hotwallets, etc.)
    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    // removes exclusion on wallets and contracts from dividends (such as CEX hotwallets, etc.)
    function includeInDividends(address account) external onlyOwner {
        dividendTracker.includeInDividends(account);
    }

    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
        tradingActiveBlock = block.number;
        earlyBuyPenaltyEnd = block.timestamp + 72 hours;
    }

    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateMaxAmount(uint256 newNum) external onlyOwner {
        require(newNum >= ((totalSupply() * 5) / 1000), "Cannot set maxTransactionAmount lower than 0.5%");
        maxTransactionAmount = newNum;
    }

    function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
        require(newNum >= (totalSupply() / 100), "Cannot set maxWallet lower than 1%");
        maxWallet = newNum;
    }

    function updateFees(
        uint256 _marketingFee,
        uint256 _rewardsFee,
        uint256 _liquidityFee
    ) external onlyOwner {
        marketingFee = _marketingFee;
        rewardsFee = _rewardsFee;
        liquidityFee = _liquidityFee;
        totalFees = marketingFee + rewardsFee + liquidityFee;
        require(totalFees <= 20, "Must keep fees at 20% or less");
    }

    function updateSellPenalty(uint256 sellFactor) external onlyOwner {
        require(sellFactor >= 100 && sellFactor <= 150, "sellFactor must be between 100 and 150");
        sellFeeIncreaseFactor = sellFactor;
    }

    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
        emit ExcludedMaxTransactionAmount(updAds, isEx);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        excludeFromMaxTransaction(pair, value);

        if (value) {
            dividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function setIsExcludedFromProcessing(address account, bool excluded) external onlyOwner {
        _isExcludedFromProcessing[account] = excluded;
    }

    function updateMarketingWallet(address newMarketingWallet) external onlyOwner {
        excludeFromFees(newMarketingWallet, true);
        emit marketingWalletUpdated(newMarketingWallet, marketingWallet);
        marketingWallet = newMarketingWallet;
    }

    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue <= 500000, " gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed(address rewardToken) external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed(rewardToken);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account, address rewardToken) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account, rewardToken);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.holderBalance(account);
    }

    function getAccountDividendsInfo(address account, address rewardToken)
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
        return dividendTracker.getAccount(account, rewardToken);
    }

    function getAccountDividendsInfoAtIndex(uint256 index, address rewardToken)
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
        return dividendTracker.getAccountAtIndex(index, rewardToken);
    }

    function processDividendTracker(uint256 gas) external {
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function getNumberOfDividends() external view returns (uint256) {
        return dividendTracker.totalBalance();
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        transferDelayEnabled = false;
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (!tradingActive) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active yet.");
        }

        if (limitsInEffect) {
            if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !swapping) {
                if (to != uniswapV2Pair && block.number <= tradingActiveBlock + 10) {
                    boughtEarly[to] = true;
                    emit BoughtEarly(to);
                }

                // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.
                if (transferDelayEnabled) {
                    if (to != owner() && to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
                        require(
                            _holderLastTransferTimestamp[tx.origin] < block.number,
                            "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
                        );
                        _holderLastTransferTimestamp[tx.origin] = block.number;
                    }
                }

                //when buy
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                    require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the maxTransactionAmount.");
                    require(amount + balanceOf(to) <= maxWallet, "Exceeds Max Wallet");
                }
                //when sell
                else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                    require(amount <= maxTransactionAmount, "Sell transfer amount exceeds the maxTransactionAmount.");
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(amount + balanceOf(to) <= maxWallet, "Exceeds Max Wallet");
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        bool canProcess = !_isExcludedFromProcessing[from] && !_isExcludedFromProcessing[to];

        if (
            canSwap &&
            swapEnabled &&
            canProcess &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;

            if (totalFees > 0) {
                uint256 sellTokens = balanceOf(address(this));
                swapBack(sellTokens);
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee && totalFees > 0) {
            uint256 fees = amount.mul(totalFees).div(100);

            // snipers / bots pay 5x fees to exit for 24 hours OR if the wallet bought in the same block that a buyback occurred to discourage bots from stealing liquidity.
            if (boughtEarly[from] && automatedMarketMakerPairs[to] && earlyBuyPenaltyEnd > block.timestamp) {
                fees = fees * 5;
                super._transfer(from, address(this), fees); // take standard fees
            } else {
                if (automatedMarketMakerPairs[to]) {
                    fees = fees.mul(sellFeeIncreaseFactor).div(100);
                }
                super._transfer(from, address(this), fees);
            }
            amount = amount.sub(fees);
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping && canProcess) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0xdead),
            block.timestamp
        );
    }

    function swapBack(uint256 contractTokenBalance) internal {
        uint256 amountToLiquify = contractTokenBalance.mul(liquidityFee).div(totalFees).div(2);
        uint256 amountToSwap = contractTokenBalance.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uint256 balanceBefore = address(this).balance;

        swapTokensForEth(amountToSwap);

        uint256 amountBNB = address(this).balance.sub(balanceBefore);

        uint256 totalBNBFee = totalFees.sub(liquidityFee.div(2));

        uint256 amountBNBLiquidity = amountBNB.mul(liquidityFee).div(totalBNBFee).div(2);
        uint256 amountBNBReflection = amountBNB.mul(rewardsFee).div(totalBNBFee);
        uint256 amountBNBMarketing = amountBNB.mul(marketingFee).div(totalBNBFee);

        (bool success, ) = address(dividendTracker).call{value: amountBNBReflection}("");

        (success, ) = address(marketingWallet).call{value: amountBNBMarketing}("");

        if (amountToLiquify > 0) {
            addLiquidity(amountToLiquify, amountBNBLiquidity);
        }
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool) {
        require(newAmount < totalSupply(), "Swap amount cannot be higher than total supply.");
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        // require(newAmount <= (totalSupply() * 1) / 1000, "Swap amount cannot be higher than 0.1% total supply.");
        swapTokensAtAmount = newAmount;
        return true;
    }

    // useful for buybacks or to reclaim any BNB on the contract in a way that helps holders.
    function buyBackTokens(uint256 bnbAmountInWei) external onlyOwner {
        // generate the uniswap pair path of weth -> eth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmountInWei}(
            0, // accept any amount of Ethereum
            path,
            address(0xdead),
            block.timestamp
        );
    }
}
