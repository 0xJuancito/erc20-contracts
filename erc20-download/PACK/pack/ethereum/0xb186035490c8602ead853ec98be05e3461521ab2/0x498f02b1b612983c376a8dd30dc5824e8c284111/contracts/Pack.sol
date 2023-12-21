// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

/// @notice Pack main contract
/// @custom:security-contact milkbeard5@gmail.com
contract Pack is Initializable, ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    /// @notice The Uniswap router used for internal swaps
    IUniswapV2Router02 public uniswapRouter;
    /// @notice The Uniswap pair to send liquidity to
    address public uniswapPair;

    /// @notice The dividend tracker is a separate un-tradable ERC20 token that is used to determine dividend payouts
    address public dividendTracker;

    /// @notice The maximum amount of tokens allowed in any one wallet (Initially max supply)
    uint256 public maxWalletAmount;

    /// @notice The maximum amount of tokens allowed in any one transaction (Initially max supply)
    uint256 public maxTxAmount;

    bool private _swapping;
    /// @notice The minimum tokens to accumulate before calling `swapAndLiquify` (Initially 0.01% of supply)
    uint256 public minimumTokensBeforeSwap;
    /// @notice The amount of gas to use to process wallet rewards during a transaction
    uint256 public gasForProcessing;

    /// @notice The wallet that will receive fees paid via the marketing tax
    address public marketingWallet;
    /// @notice The wallet that will receive LP from fees paid via the liquidity tax
    address public liquidityWallet;

    mapping(address => bool) private _isAllowedToTradeWhenDisabled;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromMaxTransactionLimit;
    mapping(address => bool) private _isExcludedFromMaxWalletLimit;
    mapping(address => bool) private automatedMarketMakerPairs;

    uint256 private _liquidityFee;
    uint256 private _marketingFee;
    uint256 private _rewardFee;
    uint256 private _totalFee;

    /// @notice antibot for launch, can be removed on contract upgrade
    bool private twoBlockLock;
    uint256 private unpauseBlock;

    uint256 private liquidityFeeOnBuy;
    uint256 private liquidityFeeOnSell;
    uint256 private marketingFeeOnBuy;
    uint256 private marketingFeeOnSell;
    uint256 private holdersFeeOnBuy;
    uint256 private holdersFeeOnSell;
    uint256 private totalFeeOnBuy;
    uint256 private totalFeeOnSell;

    address[] private tokenToETHPath;

    uint256 private _liquidityTokensToSwap;
    uint256 private _marketingTokensToSwap;
    uint256 private _holdersTokensToSwap;

    mapping (address => bool) private blacklist;
    uint256 public nonExcludedSupply;
    uint256 public magnifiedDividendPerShare;

    mapping(address => bool) internal excludedFromDividends;
    mapping(address => int256) public magnifiedDividendCorrections;
    mapping(address => uint256) internal withdrawnDividends;
    /// @notice The current token used for rewards
    address[] public rewardTokens;

    event Claim(address indexed account, uint256 indexed amount, bool indexed automatic);
    event DividendsSent(uint256 indexed tokensSwapped);
    event DividendTokenChange(address indexed newDividendToken);
    event FeesApplied(
        uint256 indexed marketingFee,
        uint256 indexed holdersFee
    );
    event DividendsDistributed(address indexed from, uint256 indexed weiAmount);
    event DividendWithdrawn(address indexed to, uint256 indexed weiAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice This function initializes the proxy contract
    /// @dev The tracker factory is create separately to avoid bloating the main contract
    function initialize(address multisig) public initializer {
        __ERC20_init("Pack", "PACK");
        __Ownable_init();
        __UUPSUpgradeable_init();

        _pause();

        twoBlockLock = true;
        unpauseBlock = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

        marketingWallet = multisig;
        liquidityWallet = multisig;

        uint256 initialSupply = 1000000000 * (10 ** 18);

        gasForProcessing = 0;
        minimumTokensBeforeSwap = SafeMath.div(initialSupply, 10000);

        // 2%
        maxWalletAmount = initialSupply.div(50);
        // 1%
        maxTxAmount = initialSupply.div(100);

        IUniswapV2Router02 _uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        address _uniswapPair = IUniswapV2Factory(_uniswapRouter.factory())
            .createPair(address(this), _uniswapRouter.WETH());
        uniswapRouter = _uniswapRouter;
        uniswapPair = _uniswapPair;
        automatedMarketMakerPairs[uniswapPair] = true;

        liquidityFeeOnBuy = 30;
        liquidityFeeOnSell = 30;
        marketingFeeOnBuy = 30;
        marketingFeeOnSell = 30;
        holdersFeeOnBuy = 30;
        holdersFeeOnSell = 30;
        totalFeeOnBuy = 90;
        totalFeeOnSell = 90;

        tokenToETHPath = new address[](2);
        tokenToETHPath[0] = address(this);
        tokenToETHPath[1] = uniswapRouter.WETH();

        dividendTracker = 0x000000000000000000000000000000000000dEaD;

        _isExcludedFromFee[multisig] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(dividendTracker)] = true;

        _isAllowedToTradeWhenDisabled[multisig] = true;

        _isExcludedFromMaxTransactionLimit[address(dividendTracker)] = true;
        _isExcludedFromMaxTransactionLimit[address(this)] = true;
        _isExcludedFromMaxTransactionLimit[multisig] = true;

        _isExcludedFromMaxWalletLimit[_uniswapPair] = true;
        _isExcludedFromMaxWalletLimit[address(dividendTracker)] = true;
        _isExcludedFromMaxWalletLimit[address(_uniswapRouter)] = true;
        _isExcludedFromMaxWalletLimit[address(this)] = true;
        _isExcludedFromMaxWalletLimit[multisig] = true;

        _mint(multisig, initialSupply);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    /// @notice Pauses trading for the token
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }
    /// @notice Unpauses trading for the token
    function unpause() external onlyOwner whenPaused {
        unpauseBlock = block.number + 2;
        _unpause();
    }

    function initializeTracker() external onlyOwner {
        nonExcludedSupply = totalSupply();

        address [] memory reward = new address[](1);
        reward[0] = 0x9813037ee2218799597d83D4a5B6F3b6778218d9;
        rewardTokens = reward;
        excludeFromDividends(uniswapPair, true);
        excludeFromDividends(address(this), true);
        excludeFromDividends(0x000000000000000000000000000000000000dEaD, true);
        excludeFromDividends(0x0000000000000000000000000000000000000000, true);
        excludeFromDividends(0x1d18541BB097aB51A7F6C7d44B47742Eb1e782C2, true);
        excludeFromDividends(0x759723f0080210e68f69071Ccd883431BB6d1618, true);
        excludeFromDividends(0x4b0f0D3c279A8Ff8552fa806C882ec7E9b42Acb1, true);

        _approve(address(this), address(uniswapRouter), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }

    /// @notice Sets whether an address is an LP pair or not. This is used to determine if fees should be applied or not
    /// @param pair The LP pair address to add to the list of AMMs
    /// @param value true if the address should be considered and AMM pair, false otherwise
    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        automatedMarketMakerPairs[pair] = value;
        excludeFromDividends(pair, value);
    }
    /// @notice Adds or removes a wallet from the blacklist
    /// @param account The account to add or remove from the blacklist
    /// @param isBlacklisted true if yes, false if no
    function blacklistAddress(address account, bool isBlacklisted) external onlyOwner {
        blacklist[account] = isBlacklisted;
    }
    /// @notice Adds or removes a wallet from the whitelist
    /// @param account The account to add or remove from the whitelist
    /// @param isWhitelisted true if yes, false if no
    function whitelistAddress(address account, bool isWhitelisted) external onlyOwner {
        _isExcludedFromFee[account] = isWhitelisted;
        _isExcludedFromMaxWalletLimit[account] = isWhitelisted;
        _isExcludedFromMaxTransactionLimit[account] = isWhitelisted;
    }
    /// @notice Sets a boolean that determines if the account can trading when the contract is paused
    /// @param account The account to allow to trade when paused.
    /// @param allowed true if the account is allowed to trade while paused, false otherwise
    function allowTradingWhenDisabled(address account, bool allowed) external onlyOwner {
        _isAllowedToTradeWhenDisabled[account] = allowed;
    }
    /// @notice Sets a boolean that determines if the account is exempt from fees
    /// @param account The account to exempt from fees
    /// @param excluded true if the account is excluded from fees, false otherwise
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        require(account != address(this), "Account != contract");
        _isExcludedFromFee[account] = excluded;
    }

    /// @notice Sets a boolean that determines if the account is exempt from the max transaction limit
    /// @param account The account to exempt from the max transaction limit
    /// @param excluded true if the account is exempt from the max transaction limit, false otherwise
    function excludeFromMaxTransactionLimit(address account, bool excluded) external onlyOwner {
        _isExcludedFromMaxTransactionLimit[account] = excluded;
    }
    /// @notice Sets a boolean that determines if the account is exempt from the max wallet limit
    /// @param account The account to exempt from the max wallet limit
    /// @param excluded true if the account is exempt from the max wallet limit, false otherwise
    function excludeFromMaxWalletLimit(address account, bool excluded) external onlyOwner {
        _isExcludedFromMaxWalletLimit[account] = excluded;
    }
    /// @notice Sets the liquidity and marketing wallets that will receive fees
    /// @param newLiquidityWallet The new  wallet to receive liquidity fees
    /// @param newMarketingWallet The new wallet to receive marketing fees
    function setWallets(address newLiquidityWallet, address newMarketingWallet) external onlyOwner {
        require(newLiquidityWallet != address(0), "liquidity wallet can't be 0");
        require(newMarketingWallet != address(0), "marketing wallet can't be 0");

        liquidityWallet = newLiquidityWallet;
        marketingWallet = newMarketingWallet;
    }
    /// @notice Get the fees incurred on buys
    /// @return liquidityFee The buy fee applied to liquidity
    /// @return marketingFee The buy fee applied to marketing
    /// @return holdersFee The buy fee applied to rewards for the holders
    function getBaseBuyFees() external view returns (uint256 liquidityFee, uint256 marketingFee, uint256 holdersFee){
        return (liquidityFeeOnBuy, marketingFeeOnBuy, holdersFeeOnBuy);
    }
    /// @notice Get the fees incurred on sells
    /// @return liquidityFee The sell fee applied to liquidity
    /// @return marketingFee The sell fee applied to marketing
    /// @return holdersFee The sell fee applied to rewards for the holders
    function getBaseSellFees() external view returns (uint256 liquidityFee, uint256 marketingFee, uint256 holdersFee){
        return (liquidityFeeOnSell, marketingFeeOnSell, holdersFeeOnSell);
    }
    /// @notice Sets the fees that will be applied to buys (Total fees can not be greater than 15%)
    /// @param _liquidityFeeOnBuy The buy fee in % that will be send to the liquidity wallet
    /// @param _marketingFeeOnBuy The buy fee in % that will be sent to the marketing wallet
    /// @param _rewardFeeOnBuy The buy fee in % that will be used to pay dividend rewards
    function setBaseFeesOnBuy(uint256 _liquidityFeeOnBuy, uint256 _marketingFeeOnBuy, uint256 _rewardFeeOnBuy) external onlyOwner {
        require((_liquidityFeeOnBuy + _marketingFeeOnBuy + _rewardFeeOnBuy) <= 15, "Buy taxes !> 15%");
        liquidityFeeOnBuy = _liquidityFeeOnBuy;
        marketingFeeOnBuy = _marketingFeeOnBuy;
        holdersFeeOnBuy = _rewardFeeOnBuy;
        totalFeeOnBuy = _liquidityFeeOnBuy + _marketingFeeOnBuy + _rewardFeeOnBuy;
    }
    /// @notice Sets the fees that will be applied to sells (Total fees can not be greater than 15%)
    /// @param _liquidityFeeOnSell The sell fee in % that will be send to the liquidity wallet
    /// @param _marketingFeeOnSell The sell fee in % that will be sent to the marketing wallet
    /// @param _rewardFeeOnSell The sell fee in % that will be used to pay dividend rewards
    function setBaseFeesOnSell(uint256 _liquidityFeeOnSell, uint256 _marketingFeeOnSell, uint256 _rewardFeeOnSell) external onlyOwner {
        require((_liquidityFeeOnSell + _marketingFeeOnSell + _rewardFeeOnSell) <= 15, "Sell taxes !> 15%");
        liquidityFeeOnSell = _liquidityFeeOnSell;
        marketingFeeOnSell = _marketingFeeOnSell;
        holdersFeeOnSell = _rewardFeeOnSell;
        totalFeeOnSell = _liquidityFeeOnSell + _marketingFeeOnSell + _rewardFeeOnSell;
    }

    /// @notice The maximum transaction amount (Must be > 1% of supply)
    /// @param newMaxTxAmount The maximum transaction amount to set
    function setMaxTransactionAmount(uint256 newMaxTxAmount) external onlyOwner {
        require((newMaxTxAmount >= (totalSupply().div(1000))), "Error: max tx lower than 1%");
        maxTxAmount = newMaxTxAmount;
    }
    /// @notice The maximum wallet amount (Must be > 1% of supply)
    /// @param newMaxWalletAmount The maximum wallet amount to set
    function setMaxWalletAmount(uint256 newMaxWalletAmount) external onlyOwner {
        require((newMaxWalletAmount >= (totalSupply().div(1000))), "Error: max wallet lower than 1%");
        maxWalletAmount = newMaxWalletAmount;
    }
    /// @notice The minimum amount of tokens to accumlate before calling `swapAndLiquify`
    /// @param newMinTokensBeforeSwap The minimum tokens before swap to set
    function setMinimumTokensBeforeSwap(uint256 newMinTokensBeforeSwap) external onlyOwner {
        require(newMinTokensBeforeSwap >= 10 ** 18, "Min must be >= 10**18" );
        minimumTokensBeforeSwap = newMinTokensBeforeSwap;
    }
    /// @notice Claims ETH overflow from math precision remainders
    /// @return success true if the transfer succeeded, false otherwise
    function claimETHOverflow(uint256 amount) external onlyOwner returns (bool success){
        require(amount <= address(this).balance, "amt > balance");
        (bool _success,) =  address(owner()).call{value : amount}("");
        resetDividendShares();
        return _success;
    }
    /// @notice Allows retrieval of any ERC20 token that was sent to the contract address
    /// @return success true if the transfer succeeded, false otherwise
    function rescueToken(address tokenAddress) external onlyOwner returns (bool success) {
        return ERC20(tokenAddress).transfer(msg.sender, ERC20(tokenAddress).balanceOf(address(this)));
    }
    /// @notice The main function called during a transfer.  First it determines if a transfer is possible by making
    /// sure the contract is not paused and that all limits are adhered to. Taxes are adjust based on whether or not
    /// the transaction is being made by an AMM (no wallet to wallet taxes). If the amount of accumulated tokens
    /// is greater than the minimum required to swap then `swapAndLiquify` is called which pays out liquidity
    /// taxes, marketing taxes and sends eth for dividends to the tracker. Fees are applied and the dividend
    /// tracker token balances are updated to reflect the post transfer token amounts.
    /// @param from Where the tokens are being transferred from
    /// @param to Where the tokens are being transferred to
    /// @param amount The amount of tokens to transfer
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!blacklist[from], "sender address is blacklisted");
        require(!blacklist[msg.sender], "sender address is blacklisted");
        require(!blacklist[to], "recipient address is blacklisted");
        require(!blacklist[to], "recipient address is blacklisted");
        if (!_isAllowedToTradeWhenDisabled[from] && !_isAllowedToTradeWhenDisabled[to]) {
            require(!paused(), "Trading disabled");
            if (!_isExcludedFromMaxTransactionLimit[to] && !_isExcludedFromMaxTransactionLimit[from]) {
                require(amount <= maxTxAmount, "Exceeds max");
            }
            if (!_isExcludedFromMaxWalletLimit[to]) {
                require(balanceOf(to).add(amount) <= maxWalletAmount, "Exceeds max");
            }
        }
        _adjustTaxes(automatedMarketMakerPairs[from],  automatedMarketMakerPairs[to]);
        if (
            balanceOf(address(this)) >= minimumTokensBeforeSwap &&
            !_swapping &&
            _totalFee > 0 &&
            automatedMarketMakerPairs[to]
        ) {
            _swapping = true;
            _swapAndDistribute();
            _swapping = false;
        }
        if (!_swapping && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            uint256 fee = amount.mul(_totalFee).div(100);

            _marketingTokensToSwap += amount.mul(_marketingFee).div(100);
            _holdersTokensToSwap += amount.mul(_rewardFee).div(100);

            amount = amount.sub(fee);
            super._transfer(from, address(this), fee);
            emit FeesApplied(_marketingFee, _rewardFee);
        }

        super._transfer(from, to, amount);

        // Dividend Corrections
        int256 _magCorrection = SafeCast.toInt256(magnifiedDividendPerShare.mul(amount));
        magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
        magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
        if (excludedFromDividends[from]) {
            nonExcludedSupply = nonExcludedSupply.add(amount);
        } else if(excludedFromDividends[to]) {
            nonExcludedSupply = nonExcludedSupply.sub(amount);
        }
    }

    /// @notice Adjusts taxes to remove wallet to wallet taxing
    /// @param isBuyFromLp true if this buy is coming from an AMM
    /// @param isSellToLp true if this sell is coming from an AMM
    function _adjustTaxes(bool isBuyFromLp, bool isSellToLp) internal {
        if (!isBuyFromLp && !isSellToLp) {
            _marketingFee = 0;
            _rewardFee = 0;
            _totalFee = 0;
        } else if (isSellToLp && isBuyFromLp) {
            _marketingFee = 10;
            _rewardFee = 10;
            _totalFee = _marketingFee + _rewardFee;
        } else if (isSellToLp) {
            _marketingFee = marketingFeeOnSell;
            _rewardFee = holdersFeeOnSell;
            _totalFee = _marketingFee + _rewardFee;
        } else {
            _marketingFee = marketingFeeOnBuy;
            _rewardFee = holdersFeeOnBuy;
            _totalFee = _marketingFee + _rewardFee;
        }
    }

    /// @notice Takes accumulated taxes disperses them to the proper place (marketing, lp or dividends)
    function _swapAndDistribute() internal returns (bool distributed){
        uint256 initialETHBalance = address(this).balance;

        _swapTokensForETH(balanceOf(address(this)));

        uint256 totalETHFee = _marketingTokensToSwap.add(_holdersTokensToSwap);

        uint256 ethBalanceAfterSwap = address(this).balance.sub(initialETHBalance);
        uint256 amountETHMarketing = ethBalanceAfterSwap.mul(_marketingTokensToSwap).div(totalETHFee);
        uint256 amountETHHolders = ethBalanceAfterSwap.sub(amountETHMarketing);
        (bool _distributed,) = payable(marketingWallet).call{value : amountETHMarketing, gas : 30000}("");

        distributeDividends(amountETHHolders);
        emit DividendsSent(amountETHHolders);

        _marketingTokensToSwap = 0;
        _holdersTokensToSwap = 0;
        return _distributed;
    }

    /// @notice Internal swap of tokens to ETH
    /// @param tokenAmount The amount of tokens to swap to ETH
    function _swapTokensForETH(uint256 tokenAmount) internal {
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            1, // accept any amount of ETH
            tokenToETHPath,
            address(this),
            block.timestamp
        );
    }

    // Dividend tracking functionality

    /// @notice Received funds are calculated and added to total dividends distributed
    receive() external payable {
        distributeDividends(msg.value);
    }

    /// @notice The reward tokens to pay out dividends in
    /// @param tokens The token addresses of the rewards (use 0x0 for < 3)
    function setRewardTokens(address[] calldata tokens) external onlyOwner {
        require(tokens.length <=3, "max 3 rewards");
        rewardTokens = tokens;
    }

    /// @notice The uniswap router to use for internal swaps
    /// @param router The uniswap swap router
    function setUniswapRouter(IUniswapV2Router02 router) external onlyOwner {
        uniswapRouter = router;
        excludeFromDividends(address(uniswapRouter), true);
    }

    /// @notice Excludes a wallet from dividends
    /// @param account The address to exclude from dividends
    /// @param value true if the address should be excluded from dividends, false otherwise
    function excludeFromDividends(address account, bool value) public onlyOwner {
        excludedFromDividends[account] = value;
        if (value) {
            nonExcludedSupply = nonExcludedSupply.sub(balanceOf(account));
        } else {
            nonExcludedSupply = nonExcludedSupply.add(balanceOf(account));
        }
    }

    /// @notice Gets account information by address
    /// @param _account The account to get information for
    /// @return withdrawableDividends The amount of dividends this account can withdraw
    /// @return totalDividends The total dividends this account has earned
    function getAccount(address _account)
    external view returns (
        uint256 withdrawableDividends,
        uint256 totalDividends) {

        totalDividends = accumulativeDividendOf(_account);
        withdrawableDividends = totalDividends.sub(withdrawnDividends[_account]);
    }

    function claimRewardsForAccounts(address[] calldata accounts) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; ){
            claimRewardFor(accounts[i]);
            unchecked {
                i++;
            }
        }
    }

    function claimRewardFor(address account) internal {
        if(excludedFromDividends[account]){
            return;
        }
        uint256 _withdrawableDividend = dividendOf(account).div(rewardTokens.length);
        for(uint256 i = 0; i < rewardTokens.length; ){
            if (_withdrawableDividend > 0) {
                swapETHForTokensAndWithdrawDividend(account, rewardTokens[i], _withdrawableDividend);
                withdrawnDividends[account] = withdrawnDividends[account].add(_withdrawableDividend);
            }
            unchecked {
                i++;
            }
        }
    }

    function claimReward() external {
        claimRewardFor(msg.sender);
    }

    function swapETHForTokensAndWithdrawDividend(address account, address reward, uint256 ethAmount) internal {
        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        path[1] = reward;
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value : ethAmount}(
            1, // accept any amount of tokens
            path,
            account,
            block.timestamp
        );
    }

    /// @notice Distributes ether to token holders as dividends.
    /// @dev It reverts if the total supply of tokens is 0.
    /// It emits the `DividendsDistributed` event if the amount of received ether is greater than 0.
    /// About undistributed ether:
    ///   In each distribution, there is a small amount of ether not distributed,
    ///     the magnified amount of which is
    ///     `(msg.value * magnitude) % totalSupply()`.
    ///   With a well-chosen `magnitude`, the amount of undistributed ether
    ///     (de-magnified) in a distribution can be less than 1 wei.
    ///   We can actually keep track of the undistributed ether in a distribution
    ///     and try to distribute it in the next distribution,
    ///     but keeping track of such data on-chain costs much more than
    ///     the saved ether, so we don't do that.
    function distributeDividends(uint256 amount) internal {
        require(nonExcludedSupply > 0);
        if (amount > 0) {
            magnifiedDividendPerShare = magnifiedDividendPerShare.add(
                (amount).mul(2 ** 128) / nonExcludedSupply
            );
            emit DividendsDistributed(msg.sender, amount);
        }
    }

    function resetDividendShares() public onlyOwner {
        require(nonExcludedSupply > 0);
        if (address(this).balance > 0) {
            magnifiedDividendPerShare = (address(this).balance).mul(2 ** 128) / nonExcludedSupply;
        }
    }

    function resetWithdrawnDividends(address account, uint256 amount) public onlyOwner {
        withdrawnDividends[account] = amount;
    }

    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function dividendOf(address account) internal view returns(uint256) {
        return withdrawableDividendOf(account);
    }

    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function withdrawableDividendOf(address account) internal view returns(uint256) {
        return accumulativeDividendOf(account).sub(withdrawnDividends[account]);
    }

    /// @notice View the amount of dividend in wei that an address has withdrawn.
    /// @return The amount of dividend in wei that `_owner` has withdrawn.
    function withdrawnDividendOf(address account) internal view returns(uint256) {
        return withdrawnDividends[account];
    }


    /// @notice View the amount of dividend in wei that an address has earned in total.
    /// @dev accumulativeDividendOf(account) = withdrawableDividendOf(account) + withdrawnDividendOf(account)
    /// = (magnifiedDividendPerShare * balanceOf(account) + magnifiedDividendCorrections[account]) / magnitude
    /// @return The amount of dividend in wei that `_owner` has earned in total.
    function accumulativeDividendOf(address account) internal view returns(uint256) {
        int256 correction = SafeCast.toInt256(magnifiedDividendPerShare.mul(balanceOf(account))).add(magnifiedDividendCorrections[account]);
        if(correction < 0) correction = SafeCast.toInt256(magnifiedDividendPerShare.mul(balanceOf(account)));
        return SafeCast.toUint256(correction) / (2 ** 128);
    }
}