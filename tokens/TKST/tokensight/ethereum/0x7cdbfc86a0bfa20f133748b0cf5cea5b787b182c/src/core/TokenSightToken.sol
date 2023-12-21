// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external;
}

contract TokenSightToken {
    /*//////////////////////////////////////////////////////////////
                              ERRORS 
    //////////////////////////////////////////////////////////////*/

    error ReceiverBlacklisted();
    error SenderBlacklisted();
    error InvalidSenderAddress();
    error InvalidReceiverAddress();
    error InvalidTokenAddress();
    error BuyFeesTooHigh();
    error SellFeesTooHigh();
    error InvalidMarketMakerPair();
    error BlacklistAlreadyRenounced();
    error InvalidAccountForBlacklist();
    error SwapAmountTooLow();
    error SwapAmountTooHigh();
    error MaxWalletAmountTooLow();
    error MaxTransactionAmountTooLow();
    error SellAmountAboveMaxTransactionAmount();
    error BuyAmountAboveMaxTransactionAmount();
    error MaxAmountForWalletExceeded();
    error InvalidTreasuryWalletAddress();
    error InvalidRevenueShareWalletAddress();
    error InvalidOwnerAddress();
    error InvalidUniswapV2RouterAddress();
    error InvalidUniswapV2FactoryAddress();
    error InvalidWethAddress();
    error NotOwner();
    error AlreadyStarted();
    error NotStarted();
    error FeesAlreadyReduced();
    error FeesAlreadyDisabled();
    error SafeTransferEthError();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event ExcludedFromFees(address indexed account, bool isExcluded);
    event ExcludedFromMaxTransactionAmount(address indexed account, bool isExcluded);
    event AutomatedMarketMakerPairSet(address indexed pair, bool value);
    event RevenueShareWalletAddressUpdated(address indexed newWallet);
    event TreasuryWalletAddressUpdated(address indexed newWallet);
    event OwnerUpdated(address indexed newOwner);
    event SwappedAndLiquified(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event BuyFeesUpdated(uint256 revenueShareFeePercent, uint256 liquidityFeePercent, uint256 treasuryFeePercent);
    event SellFeesUpdated(uint256 revenueShareFeePercent, uint256 liquidityFeePercent, uint256 treasuryFeePercent);
    event LimitsRemoved();
    event LiquifyThresholdAmountUpdated(uint256 newAmount);
    event MaxTxAmountUpdated(uint256 newAmount);
    event MaxWalletAmountUpdated(uint256 newAmount);
    event BlacklistRenounced();
    event Blacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event FeesDisabled();
    

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant _DEAD_ADDRESS = address(0xdead);

    uint256 private constant _MAX_LIQUIFY_THRESHOLD_MULTIPLIER = 10;
    uint256 public constant MAX_FEES_PERCENT_THRESHOLD = 5;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STATE VARS
    //////////////////////////////////////////////////////////////*/

    string public name = "TokenSight Token";
    string public symbol = "TKST";
    uint8 public immutable decimals = 18;
    uint256 public totalSupply;
    mapping(address account => uint256 amount) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              TOKENSIGHT STATE VARS
    //////////////////////////////////////////////////////////////*/

    address public deployer;
    address public owner;
    address public revenueShareWallet;
    address public treasuryWallet;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public immutable wethAddress;

    uint256 public maxTxAmount = 1_000_000 * 1e18;
    uint256 public maxWalletAmount = 1_000_000 * 1e18;
    uint256 public liquifyThresholdAmount = 50_000 * 1e18;

    bool public limitsInEffect = true;
    bool public started = false;

    bool public blacklistRenounced = false;

    uint256 public buyTotalFeesPercent = 40;
    uint256 public buyRevenueShareFeePercent = 2;
    uint256 public buyLiquidityFeePercent = 1;
    uint256 public buyTreasuryFeePercent = 37;

    uint256 public sellTotalFeesPercent = 40;
    uint256 public sellRevenueShareFeePercent = 2;
    uint256 public sellLiquidityFeePercent = 1;
    uint256 public sellTreasuryFeePercent = 37;

    uint256 public revenueShareTokens;
    uint256 public liquidityTokens;
    uint256 public treasuryTokens;

    // Fees
    bool public feesReduced = false;
    bool public feesDisabled = false;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) public blacklisted;

    // exclude from fees and max transaction amount
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    bool private _liquifying;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _revenueShareWallet,
        address _treasuryWallet,
        address _owner,
        address _univ2Router,
        address _univ2Factory,
        address _wethAddress
    ) {
        if (_revenueShareWallet == address(0)) revert InvalidRevenueShareWalletAddress();
        if (_treasuryWallet == address(0)) revert InvalidTreasuryWalletAddress();
        if (_owner == address(0)) revert InvalidOwnerAddress();
        if (_univ2Router == address(0)) revert InvalidUniswapV2RouterAddress();
        if (_univ2Factory == address(0)) revert InvalidUniswapV2FactoryAddress();
        if (_wethAddress == address(0)) revert InvalidWethAddress();

        revenueShareWallet = _revenueShareWallet;
        treasuryWallet = _treasuryWallet;
        owner = _owner;
        deployer = msg.sender;
        wethAddress = _wethAddress;

        uniswapV2Router = IUniswapV2Router02(_univ2Router);
        _excludeFromMaxTransaction(_univ2Router, true);

        uniswapV2Pair = IUniswapV2Factory(_univ2Factory).createPair(address(this), wethAddress);
        _excludeFromMaxTransaction(uniswapV2Pair, true);

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        _excludeFromFees(_owner, true);
        _excludeFromMaxTransaction(_owner, true);

        _excludeFromFees(address(this), true);
        _excludeFromMaxTransaction(address(this), true);

        _excludeFromFees(_DEAD_ADDRESS, true);
        _excludeFromMaxTransaction(_DEAD_ADDRESS, true);

        _excludeFromFees(0xD152f549545093347A162Dce210e7293f1452150, true);
        _excludeFromMaxTransaction(0xD152f549545093347A162Dce210e7293f1452150, true);

        _excludeFromFees(msg.sender, true);
        _excludeFromMaxTransaction(msg.sender, true);

        _mint(owner, 87_030_000 * 1e18);
        _mint(address(this), 10_000_000 * 1e18);
        _mint(msg.sender, 2_970_000 * 1e18);

        _approve(address(this), _univ2Router, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                        Launch
    //////////////////////////////////////////////////////////////*/

    function startEngine() external payable {
        _revertIfNotOwner();
        if (started) revert AlreadyStarted();

        uniswapV2Router.addLiquidityETH{ value: msg.value }(
            address(this), balanceOf[address(this)], 0, 0, owner, block.timestamp
        );

        started = true;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address _owner, address spender, uint256 amount) internal {
        allowance[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        _transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal transfer function. Handles all the logic for transferring and swapping
    /// tokens. It includes logic for charging fees on swapping, as well as liquifying and withdrawing
    /// tax fees.
    /// @param from The sender's address
    /// @param to The receiver's address
    /// @param amount The transfer amount
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert InvalidSenderAddress();
        if (to == address(0)) revert InvalidReceiverAddress();

        if (blacklisted[from]) revert SenderBlacklisted();
        if (blacklisted[to]) revert ReceiverBlacklisted();

        if (amount == 0) {
            _erc20transfer(from, to, 0);
            return;
        }

        if (limitsInEffect) {
            _checkLimitsOnTransfer(from, to, amount);
        }

        if (_canLiquifyAndWithdrawTaxes(from, to)) {
            _liquifying = true;
            _liquifyAndWithdrawTaxes();
            _liquifying = false;
        }

        bool takeFee = !_liquifying;

        // if the fee is disabled or account is excluded from fees, do not takae fees
        if (feesDisabled || (isExcludedFromFees[from] || isExcludedFromFees[to])) {
            takeFee = false;
        }

        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            uint256 fees = _takeFeeOnTransfer(from, to, amount);
            amount -= fees;
        }

        _erc20transfer(from, to, amount);
    }

    /// @notice Regular ERC20 transfer
    /// @param from The sender address
    /// @param to The receiver address
    /// @param amount The transfer amount
    function _erc20transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    /// @notice Check limits on transfers based on input params and internal contract state.
    /// Reverts if the transfer is invalid - not within limits.
    /// @param from The sender's address
    /// @param to The receiver's address
    /// @param amount The transfer amount
    function _checkLimitsOnTransfer(address from, address to, uint256 amount) internal view {
        address _owner = owner;
        address _deployer = deployer;

        bool isOwner = from == _owner || to == _owner;
        bool isDeployer = from == _deployer || to == _deployer;
        bool isZeroAddress = to == address(0) || to == _DEAD_ADDRESS;

        // Limits don't apply to deployer, owner, 0 addresses and when the state is liquifying
        if (!isOwner && !isDeployer && !isZeroAddress && !_liquifying) {
            /* 
            If the trading is not active and the sender or receiver are excluded from paying fees, they can transfer the
                tokens freely. Otherwise the call should revert.
            */
            if (!started) {
                if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) revert NotStarted();
            }

            /* 
                When buying and the receiver is not excluded from the MAX transaction amount,
                check if the buying amount and the receiver balance are within the maximum thresholds.
                If not, revert the call.
            */
            if (automatedMarketMakerPairs[from] && !isExcludedFromMaxTransactionAmount[to]) {
                if (amount > maxTxAmount) revert BuyAmountAboveMaxTransactionAmount();
                if (amount + balanceOf[to] > maxWalletAmount) revert MaxAmountForWalletExceeded();
            }
            /* 
                When selling and the receiver is not excluded from the max transaction amount,
                check if the selling amount is within the maximum transaction amount threshold.
                If not, revert the call.
            */
            else if (automatedMarketMakerPairs[to] && !isExcludedFromMaxTransactionAmount[from]) {
                if (amount > maxTxAmount) revert SellAmountAboveMaxTransactionAmount();
            }
            /* 
                On regular transfers (not buying or selling), when the receiver is not excluded 
                from the MAX transaction amount, check if the receiver's balance will
                be above the maximum allowed balance per wallet. If this is the case, revert the call.
            */
            else if (!isExcludedFromMaxTransactionAmount[to]) {
                if (amount + balanceOf[to] > maxWalletAmount) revert MaxAmountForWalletExceeded();
            }
        }
    }

    /// @notice Check if liquifying and withdrawing taxes can be performed, based on internal state:
    /// - amount of tokens collected is larger than the liquifying threshold amount
    /// - swapping is enabled
    /// - contract is not in liquifying state
    /// - the operation is not buy (can liquify only on transfer or sell)
    /// - sender and receiver are not excluded from fees
    /// @param from The sender's address
    /// @param to The receiver's address
    function _canLiquifyAndWithdrawTaxes(address from, address to) internal view returns (bool canLiquify) {
        bool contractHasEnoughTokensToSwap = balanceOf[address(this)] >= liquifyThresholdAmount;

        canLiquify = (
            contractHasEnoughTokensToSwap && !_liquifying && !automatedMarketMakerPairs[from]
                && !isExcludedFromFees[from] && !isExcludedFromFees[to]
        );
    }

    /// @notice Liquify and withdraw proceeds from collected taxes (buy and sell taxes).
    /// The amount of tokens to swap for ETH is capped at a certain threshold.
    /// All the tokens, except half of the tokens dedicated for liquidity are swapped for ETH.
    /// With half of the liquidity tokens and the swapped eth dedicated for liquidity, liquidity is added to the Uniswap
    /// pool.
    /// The swapped ETH which is not added to liquidity is sent to the treasury and revenue share wallets according to
    /// the fee split scheme.
    function _liquifyAndWithdrawTaxes() internal {
        uint256 contractTokenBalance = balanceOf[address(this)];
        uint256 totalTokensToSwap = liquidityTokens + revenueShareTokens + treasuryTokens;

        if (totalTokensToSwap == 0) {
            return;
        }

        if (contractTokenBalance > liquifyThresholdAmount * _MAX_LIQUIFY_THRESHOLD_MULTIPLIER) {
            contractTokenBalance = liquifyThresholdAmount * _MAX_LIQUIFY_THRESHOLD_MULTIPLIER;
        }

        /* 
        From the current contract token balance, extract only half of the tokens that will be used for liquidity.
        The other half of liquidity tokens will be swapped to eth, and we will add eth:token liquidity to the pool. */

        uint256 tokensForLiquidity = (contractTokenBalance * liquidityTokens) / totalTokensToSwap / 2;

        uint256 amountToSwapForETH = contractTokenBalance - tokensForLiquidity;
        uint256 initialETHBalance = address(this).balance;

        _swapTokensForEth(amountToSwapForETH);

        uint256 swappedEthBalance = address(this).balance - initialETHBalance;

        uint256 tokensToSwapWithoutLiquidityTokens = (totalTokensToSwap - (liquidityTokens / 2));

        uint256 ethForRevenueShare = (swappedEthBalance * revenueShareTokens) / tokensToSwapWithoutLiquidityTokens;

        uint256 ethForTreasury = (swappedEthBalance * treasuryTokens) / tokensToSwapWithoutLiquidityTokens;

        uint256 ethForLiquidity = swappedEthBalance - ethForRevenueShare - ethForTreasury;

        liquidityTokens = 0;
        revenueShareTokens = 0;
        treasuryTokens = 0;

        _safeTransferETH(treasuryWallet, ethForTreasury);

        if (tokensForLiquidity > 0 && ethForLiquidity > 0) {
            _addLiquidity(tokensForLiquidity, ethForLiquidity);
            emit SwappedAndLiquified(amountToSwapForETH, ethForLiquidity, tokensForLiquidity);
        }

        _safeTransferETH(revenueShareWallet, ethForRevenueShare);
    }

    /// @notice Swap tokens for ETH
    /// @param tokenAmount The token amount to swap for ETH
    function _swapTokensForEth(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = wethAddress;
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, 0, path, address(this), block.timestamp
        );
    }

    /// @notice Add liquidity to the uniswap pool
    /// @param tokenAmount The token amount to add
    /// @param ethAmount The ETH amount to add
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        uniswapV2Router.addLiquidityETH{ value: ethAmount }(address(this), tokenAmount, 0, 0, owner, block.timestamp);
    }

    /// @notice Take fees on transfer, if the operation is buy or sell (no fee on regular transfers)
    /// @param from The sender address
    /// @param to The receiver address
    /// @param amount The transfer amount
    /// @param fees The fees amount
    function _takeFeeOnTransfer(address from, address to, uint256 amount) internal returns (uint256 fees) {
        fees = 0;
        // on sell
        if (automatedMarketMakerPairs[to] && sellTotalFeesPercent > 0) {
            fees = (amount * sellTotalFeesPercent) / 100;
            liquidityTokens += (fees * sellLiquidityFeePercent) / sellTotalFeesPercent;
            treasuryTokens += (fees * sellTreasuryFeePercent) / sellTotalFeesPercent;
            revenueShareTokens += (fees * sellRevenueShareFeePercent) / sellTotalFeesPercent;
        }
        // on buy
        else if (automatedMarketMakerPairs[from] && buyTotalFeesPercent > 0) {
            fees = (amount * buyTotalFeesPercent) / 100;
            liquidityTokens += (fees * buyLiquidityFeePercent) / buyTotalFeesPercent;
            treasuryTokens += (fees * buyTreasuryFeePercent) / buyTotalFeesPercent;
            revenueShareTokens += (fees * buyRevenueShareFeePercent) / buyTotalFeesPercent;
        }

        if (fees > 0) {
            _erc20transfer(from, address(this), fees);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            LIMITS
    //////////////////////////////////////////////////////////////*/

    function removeLimits() external {
        _revertIfNotOwner();

        limitsInEffect = false;
        emit LimitsRemoved();
    }

    function updateLiquifyThresholdAmount(uint256 _liquifyThresholdAmount) external {
        _revertIfNotOwner();

        uint256 _totalSupply = totalSupply;

        if (_liquifyThresholdAmount < (_totalSupply * 1) / 100_000) revert SwapAmountTooLow(); // 0.001% of the supply
        if (_liquifyThresholdAmount > (_totalSupply * 5) / 1000) revert SwapAmountTooHigh(); // 0.5% of the supply
        liquifyThresholdAmount = _liquifyThresholdAmount;
        emit LiquifyThresholdAmountUpdated(_liquifyThresholdAmount);
    }

    function updateMaxTxAmount(uint256 _maxTxAmount) external {
        _revertIfNotOwner();

        if (_maxTxAmount < ((totalSupply * 1) / 1000)) revert MaxTransactionAmountTooLow(); // 0.1% of
            // the supply
        maxTxAmount = _maxTxAmount;
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function updateMaxWalletAmount(uint256 _maxWalletAmount) external {
        _revertIfNotOwner();

        if (_maxWalletAmount < ((totalSupply * 1) / 1000)) revert MaxWalletAmountTooLow(); // 0.1% of the supply
        maxWalletAmount = _maxWalletAmount;
        emit MaxWalletAmountUpdated(_maxWalletAmount);
    }

    function excludeFromMaxTransaction(address account, bool isExcluded) external {
        _revertIfNotOwner();
        _excludeFromMaxTransaction(account, isExcluded);
    }

    function _excludeFromMaxTransaction(address account, bool isExcluded) internal {
        isExcludedFromMaxTransactionAmount[account] = isExcluded;
        emit ExcludedFromMaxTransactionAmount(account, isExcluded);
    }

    function excludeFromFees(address account, bool isExcluded) external {
        _revertIfNotOwner();
        _excludeFromFees(account, isExcluded);
    }

    function _excludeFromFees(address account, bool isExcluded) internal {
        isExcludedFromFees[account] = isExcluded;
        emit ExcludedFromFees(account, isExcluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external {
        _revertIfNotOwner();

        if (pair == address(uniswapV2Pair)) revert InvalidMarketMakerPair();

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) internal {
        automatedMarketMakerPairs[pair] = value;
        emit AutomatedMarketMakerPairSet(pair, value);
    }

    /*//////////////////////////////////////////////////////////////
                               OWNER
    //////////////////////////////////////////////////////////////*/


    function updateOwner(address _owner) external {
        _revertIfNotOwner();

        if (_owner == address(0)) revert InvalidOwnerAddress();
        owner = _owner;
        emit OwnerUpdated(_owner);
    }

    function _revertIfNotOwner() internal view {
        if (msg.sender != owner) revert NotOwner();
    }

    /*//////////////////////////////////////////////////////////////
                                FEES    
    //////////////////////////////////////////////////////////////*/

    function reduceFees() external {
        if (feesReduced) revert FeesAlreadyReduced();
        updateBuyFees(2, 1, 2);
        updateSellFees(2, 1, 2);
        feesReduced = true;
    }

    function updateBuyFees(
        uint256 _revenueShareFeePercent,
        uint256 _liquidityFeePercent,
        uint256 _treasuryFeePercent
    )
        public
    {
        _revertIfNotOwner();

        if (feesDisabled) revert FeesAlreadyDisabled();

        if ((_revenueShareFeePercent + _liquidityFeePercent + _treasuryFeePercent) > MAX_FEES_PERCENT_THRESHOLD) {
            revert BuyFeesTooHigh();
        }
        buyRevenueShareFeePercent = _revenueShareFeePercent;
        buyLiquidityFeePercent = _liquidityFeePercent;
        buyTreasuryFeePercent = _treasuryFeePercent;
        buyTotalFeesPercent = _revenueShareFeePercent + _liquidityFeePercent + _treasuryFeePercent;
        emit BuyFeesUpdated(_revenueShareFeePercent, _liquidityFeePercent, _treasuryFeePercent);
    }

    function updateSellFees(
        uint256 _revenueShareFeePercent,
        uint256 _liquidityFeePercent,
        uint256 _treasuryFeePercent
    )
        public
    {
        _revertIfNotOwner();

        if (feesDisabled) revert FeesAlreadyDisabled();

        if ((_revenueShareFeePercent + _liquidityFeePercent + _treasuryFeePercent) > MAX_FEES_PERCENT_THRESHOLD) {
            revert SellFeesTooHigh();
        }
        sellRevenueShareFeePercent = _revenueShareFeePercent;
        sellLiquidityFeePercent = _liquidityFeePercent;
        sellTreasuryFeePercent = _treasuryFeePercent;
        sellTotalFeesPercent = _revenueShareFeePercent + _liquidityFeePercent + _treasuryFeePercent;
        emit SellFeesUpdated(_revenueShareFeePercent, _liquidityFeePercent, _treasuryFeePercent);
    }

    function disableFees() external {
        _revertIfNotOwner();
        feesDisabled = true;
        emit FeesDisabled();
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNT MANAGEMENT    
    //////////////////////////////////////////////////////////////*/

    function updateRevenueShareWallet(address _revenueShareWallet) external {
        _revertIfNotOwner();

        if (_revenueShareWallet == address(0)) revert InvalidRevenueShareWalletAddress();
        revenueShareWallet = _revenueShareWallet;
        emit RevenueShareWalletAddressUpdated(_revenueShareWallet);
    }

    function updateTreasuryWallet(address _treasuryWallet) external {
        _revertIfNotOwner();

        if (_treasuryWallet == address(0)) revert InvalidTreasuryWalletAddress();
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletAddressUpdated(_treasuryWallet);
    }

    /*//////////////////////////////////////////////////////////////
                            BLACKLIST
    //////////////////////////////////////////////////////////////*/

    function renounceBlacklist() external {
        _revertIfNotOwner();

        blacklistRenounced = true;
        emit BlacklistRenounced();
    }

    function blacklist(address account) external {
        _revertIfNotOwner();

        if (blacklistRenounced) revert BlacklistAlreadyRenounced();
        if (account == address(uniswapV2Pair) || account == address(uniswapV2Router)) {
            revert InvalidAccountForBlacklist();
        }
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function whitelist(address account) external {
        _revertIfNotOwner();

        blacklisted[account] = false;
        emit Whitelisted(account);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function withdrawStuckToken(address token, address to) external {
        _revertIfNotOwner();

        if (token == address(0)) revert InvalidTokenAddress();
        if (to == address(0)) revert InvalidReceiverAddress();

        uint256 contractTokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, contractTokenBalance);
    }

    function withdrawStuckEth(address to) external {
        _revertIfNotOwner();

        if (to == address(0)) revert InvalidReceiverAddress();
        _safeTransferETH(to, address(this).balance);
    }

    /*//////////////////////////////////////////////////////////////
                            SAFE TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{ value: value }(new bytes(0));
        if (!success) revert SafeTransferEthError();
    }

    receive() external payable { }
}
