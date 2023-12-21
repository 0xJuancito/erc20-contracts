// SPDX-License-Identifier: AGPL-3.0-only
//
// LEETSWAP
//
// The #1 DEX for leet degens
//
//
// Website: https://leetswap.finance
// Telegram: https://t.me/LeetSwap
// Twitter: https://twitter.com/LeetSwap
//
pragma solidity =0.8.17;

import "@leetswap/interfaces/ILiquidityManageable.sol";
import "@leetswap/dex/v2/interfaces/ILeetSwapV2Router01.sol";
import "@leetswap/dex/v2/interfaces/ILeetSwapV2Factory.sol";
import "@leetswap/dex/v2/interfaces/ILeetSwapV2Pair.sol";
import "@leetswap/tokens/interfaces/IFeeDiscountOracle.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LeetToken is ERC20, Ownable, ILiquidityManageable {
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant FEE_DENOMINATOR = 1e4;
    uint256 public constant MAX_FEE = 1000;

    uint256 public burnBuyFee;
    uint256 public farmsBuyFee;
    uint256 public stakingBuyFee;
    uint256 public treasuryBuyFee;
    uint256 public totalBuyFee;

    uint256 public burnSellFee;
    uint256 public farmsSellFee;
    uint256 public stakingSellFee;
    uint256 public treasurySellFee;
    uint256 public totalSellFee;

    address public farmsFeeRecipient;
    address public stakingFeeRecipient;
    address public treasuryFeeRecipient;

    bool public tradingEnabled;
    uint256 public tradingEnabledTimestamp = 0; // 0 means trading is not active

    ILeetSwapV2Router01 public swapFeesRouter;
    IFeeDiscountOracle public feeDiscountOracle;
    address public swapPairToken;
    bool public swappingFeesEnabled;
    bool public isSwappingFees;
    uint256 public swapFeesAtAmount;
    uint256 public maxSwapFeesAmount;
    uint256 public maxWalletAmount;

    uint256 public sniperBuyBaseFee = 0;
    uint256 public sniperBuyFeeDecayPeriod = 0;
    uint256 public sniperBuyFeeBurnShare = 2500;
    bool public sniperBuyFeeEnabled = true;

    uint256 public sniperSellBaseFee = 0;
    uint256 public sniperSellFeeDecayPeriod = 0;
    uint256 public sniperSellFeeBurnShare = 2500;
    bool public sniperSellFeeEnabled = true;

    bool public pairAutoDetectionEnabled;
    bool public indirectSwapFeeEnabled;
    bool public maxWalletEnabled;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isLiquidityManager;
    mapping(address => bool) public isWhitelistedFactory;
    mapping(address => bool) public isBot;

    bool internal _isLiquidityManagementPhase;
    uint256 internal _currentCacheVersion;
    mapping(address => bool) internal _isLeetPair;
    mapping(uint256 => mapping(address => bool))
        internal _isCachedAutodetectedLeetPair;
    mapping(address => bool) internal _isExcludedFromMaxWallet;

    event BuyFeeUpdated(uint256 _fee, uint256 _previousFee);
    event SellFeeUpdated(uint256 _fee, uint256 _previousFee);
    event LeetPairAdded(address _pair);
    event LeetPairRemoved(address _pair);
    event AddressExcludedFromFees(address _address);
    event AddressIncludedInFees(address _address);
    event WhitelistedFactoryAdded(address _factory);
    event WhitelistedFactoryRemoved(address _factory);

    error TradingNotEnabled();
    error TradingAlreadyEnabled();
    error SniperBotDetected();
    error MaxWalletReached();
    error TimestampIsInThePast();
    error FeeTooHigh();
    error InvalidFeeRecipient();
    error NotLiquidityManager();
    error TransferFailed();
    error ArrayLengthMismatch();

    constructor(
        address _router,
        address _swapPairToken
    ) ERC20("leetswap.finance", "LEET") {
        ILeetSwapV2Router01 router = ILeetSwapV2Router01(_router);
        ILeetSwapV2Factory factory = ILeetSwapV2Factory(router.factory());
        swapPairToken = _swapPairToken;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[DEAD] = true;

        _isExcludedFromMaxWallet[owner()] = true;
        _isExcludedFromMaxWallet[address(this)] = true;
        _isExcludedFromMaxWallet[DEAD] = true;

        burnBuyFee = 0;
        farmsBuyFee = 0;
        stakingBuyFee = 0;
        treasuryBuyFee = 0;
        setBuyFees(burnBuyFee, farmsBuyFee, stakingBuyFee, treasuryBuyFee);

        burnSellFee = 0;
        farmsSellFee = 150;
        stakingSellFee = 100;
        treasurySellFee = 50;
        setSellFees(burnSellFee, farmsSellFee, stakingSellFee, treasurySellFee);

        farmsFeeRecipient = owner();
        stakingFeeRecipient = owner();
        treasuryFeeRecipient = owner();

        isLiquidityManager[address(router)] = true;
        isWhitelistedFactory[address(factory)] = true;

        address pair = factory.createPair(address(this), swapPairToken);
        address feesVault = ILeetSwapV2Pair(pair).fees();
        _isExcludedFromMaxWallet[feesVault] = true;
        isExcludedFromFee[feesVault] = true;
        _isLeetPair[pair] = true;
        maxWalletEnabled = true;
        // pairAutoDetectionEnabled = true;

        _mint(owner(), 1337000 * 10 ** decimals());

        swapFeesRouter = router;
        swapFeesAtAmount = (totalSupply() * 3) / 1e5;
        maxSwapFeesAmount = (totalSupply() * 4) / 1e5;
        maxWalletAmount = (totalSupply() * 1) / 1e3; // 1% of the CIRCULATING supply
    }

    modifier onlyLiquidityManager() {
        if (!isLiquidityManager[msg.sender]) {
            revert NotLiquidityManager();
        }
        _;
    }

    /************************************************************************/

    function isLeetPair(address _pair) public returns (bool isPair) {
        if (_isLeetPair[_pair]) {
            return true;
        }

        if (!pairAutoDetectionEnabled) {
            return false;
        }

        if (_isCachedAutodetectedLeetPair[_currentCacheVersion][_pair]) {
            return true;
        }

        if (_pair.code.length == 0) {
            return false;
        }

        (bool success, bytes memory data) = _pair.staticcall(
            abi.encodeWithSignature("factory()")
        );
        if (!success) return false;
        address factory = abi.decode(data, (address));
        if (factory == address(0)) return false;

        bool isVerifiedPair = isWhitelistedFactory[factory] &&
            ILeetSwapV2Factory(factory).isPair(_pair);

        (success, data) = _pair.staticcall(abi.encodeWithSignature("token0()"));
        if (!success) return false;
        address token0 = abi.decode(data, (address));
        if (token0 == address(this)) {
            if (isVerifiedPair) {
                _isCachedAutodetectedLeetPair[_currentCacheVersion][
                    _pair
                ] = true;
            }

            return true;
        }

        (success, data) = _pair.staticcall(abi.encodeWithSignature("token1()"));
        if (!success) return false;
        address token1 = abi.decode(data, (address));
        if (token1 == address(this)) {
            if (isVerifiedPair) {
                _isCachedAutodetectedLeetPair[_currentCacheVersion][
                    _pair
                ] = true;
            }

            return true;
        }

        return false;
    }

    function _shouldTakeTransferTax(
        address sender,
        address recipient
    ) internal returns (bool) {
        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) {
            return false;
        }

        return
            !_isLiquidityManagementPhase &&
            (isLeetPair(sender) || isLeetPair(recipient));
    }

    function sniperBuyFee() public view returns (uint256) {
        if (!sniperBuyFeeEnabled) {
            return 0;
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;

        if (timeSinceLaunch >= sniperBuyFeeDecayPeriod) {
            return 0;
        }

        return
            sniperBuyBaseFee -
            (sniperBuyBaseFee * timeSinceLaunch) /
            sniperBuyFeeDecayPeriod;
    }

    function sniperSellFee() public view returns (uint256) {
        if (!sniperSellFeeEnabled) {
            return 0;
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;

        if (timeSinceLaunch >= sniperSellFeeDecayPeriod) {
            return 0;
        }

        return
            sniperSellBaseFee -
            (sniperSellBaseFee * timeSinceLaunch) /
            sniperSellFeeDecayPeriod;
    }

    /************************************************************************/

    function buyFeeDiscountFor(
        address account,
        uint256 totalFeeAmount
    ) public view returns (uint256) {
        if (address(feeDiscountOracle) == address(0)) return 0;
        return feeDiscountOracle.buyFeeDiscountFor(account, totalFeeAmount);
    }

    function sellFeeDiscountFor(
        address account,
        uint256 totalFeeAmount
    ) public view returns (uint256) {
        if (address(feeDiscountOracle) == address(0)) return 0;
        return feeDiscountOracle.sellFeeDiscountFor(account, totalFeeAmount);
    }

    function _takeBuyFee(
        address sender,
        address user,
        uint256 amount
    ) internal returns (uint256) {
        if (totalBuyFee == 0) return 0;

        uint256 totalFeeAmount = (amount * totalBuyFee) / FEE_DENOMINATOR;
        uint256 feeDiscountAmount = buyFeeDiscountFor(user, totalFeeAmount);

        totalFeeAmount -= feeDiscountAmount;
        if (totalFeeAmount == 0) return 0;

        uint256 burnFeeAmount = (totalFeeAmount * burnBuyFee) / totalBuyFee;
        uint256 farmsFeeAmount = (totalFeeAmount * farmsBuyFee) / totalBuyFee;
        uint256 stakingFeeAmount = (totalFeeAmount * stakingBuyFee) /
            totalBuyFee;
        uint256 treasuryFeeAmount = totalFeeAmount -
            burnFeeAmount -
            farmsFeeAmount -
            stakingFeeAmount;

        if (burnFeeAmount > 0) super._transfer(sender, DEAD, burnFeeAmount);

        if (farmsFeeAmount > 0)
            super._transfer(sender, farmsFeeRecipient, farmsFeeAmount);

        if (stakingFeeAmount > 0)
            super._transfer(sender, stakingFeeRecipient, stakingFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _takeSellFee(
        address sender,
        address user,
        uint256 amount
    ) internal returns (uint256) {
        if (totalSellFee == 0) return 0;

        uint256 totalFeeAmount = (amount * totalSellFee) / FEE_DENOMINATOR;
        uint256 feeDiscountAmount = sellFeeDiscountFor(user, totalFeeAmount);

        totalFeeAmount -= feeDiscountAmount;
        if (totalFeeAmount == 0) return 0;

        uint256 burnFeeAmount = (totalFeeAmount * burnSellFee) / totalSellFee;
        uint256 farmsFeeAmount = (totalFeeAmount * farmsSellFee) / totalSellFee;
        uint256 stakingFeeAmount = (totalFeeAmount * stakingSellFee) /
            totalSellFee;
        uint256 treasuryFeeAmount = totalFeeAmount -
            burnFeeAmount -
            farmsFeeAmount -
            stakingFeeAmount;

        if (burnFeeAmount > 0) super._transfer(sender, DEAD, burnFeeAmount);

        if (farmsFeeAmount > 0)
            super._transfer(sender, farmsFeeRecipient, farmsFeeAmount);

        if (stakingFeeAmount > 0)
            super._transfer(sender, stakingFeeRecipient, stakingFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _takeSniperBuyFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        uint256 totalFeeAmount = (amount * sniperBuyFee()) / FEE_DENOMINATOR;
        uint256 burnFeeAmount = (totalFeeAmount * sniperBuyFeeBurnShare) /
            FEE_DENOMINATOR;
        uint256 treasuryFeeAmount = totalFeeAmount - burnFeeAmount;

        if (burnFeeAmount > 0) super._transfer(sender, DEAD, burnFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _takeSniperSellFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        uint256 totalFeeAmount = (amount * sniperSellFee()) / FEE_DENOMINATOR;
        uint256 burnFeeAmount = (totalFeeAmount * sniperSellFeeBurnShare) /
            FEE_DENOMINATOR;
        uint256 treasuryFeeAmount = totalFeeAmount - burnFeeAmount;

        if (burnFeeAmount > 0) super._transfer(sender, DEAD, burnFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (
            !(tradingEnabled && tradingEnabledTimestamp <= block.timestamp) &&
            !isExcludedFromFee[sender] &&
            !isExcludedFromFee[recipient]
        ) {
            revert TradingNotEnabled();
        }

        if (isBot[sender] || isBot[recipient]) revert SniperBotDetected();

        if (
            maxWalletEnabled &&
            !isExcludedFromMaxWallet(recipient) &&
            balanceOf(recipient) + amount > maxWalletAmount
        ) revert MaxWalletReached();

        bool takeFee = !isSwappingFees &&
            _shouldTakeTransferTax(sender, recipient);
        bool isBuy = isLeetPair(sender);
        bool isSell = isLeetPair(recipient);
        bool isIndirectSwap = (_isLeetPair[sender] ||
            _isCachedAutodetectedLeetPair[_currentCacheVersion][sender]) &&
            (_isLeetPair[recipient] ||
                _isCachedAutodetectedLeetPair[_currentCacheVersion][recipient]);
        takeFee = takeFee && (indirectSwapFeeEnabled || !isIndirectSwap);

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwapFees = contractTokenBalance >= swapFeesAtAmount;
        bool isEOATransfer = sender.code.length == 0 &&
            recipient.code.length == 0;

        if (
            canSwapFees &&
            swappingFeesEnabled &&
            !isSwappingFees &&
            !_isLiquidityManagementPhase &&
            !isIndirectSwap &&
            (isSell || isEOATransfer) &&
            !isExcludedFromFee[sender] &&
            !isExcludedFromFee[recipient]
        ) {
            isSwappingFees = true;
            _swapFees();
            isSwappingFees = false;
        }

        uint256 totalFeeAmount;
        if (takeFee) {
            if (isSell) {
                totalFeeAmount = _takeSellFee(sender, sender, amount);
                totalFeeAmount += _takeSniperSellFee(sender, amount);
            } else if (isBuy) {
                totalFeeAmount = _takeBuyFee(sender, recipient, amount);
                totalFeeAmount += _takeSniperBuyFee(sender, amount);
            }
        }

        super._transfer(sender, recipient, amount - totalFeeAmount);
    }

    /************************************************************************/

    function _swapFees() internal {
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 amountToSwap = contractTokenBalance > maxSwapFeesAmount
            ? maxSwapFeesAmount
            : contractTokenBalance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapPairToken;

        _approve(address(this), address(swapFeesRouter), amountToSwap);
        swapFeesRouter.swapExactTokensForTokens(
            amountToSwap,
            0,
            path,
            treasuryFeeRecipient,
            block.timestamp
        );
    }

    /************************************************************************/

    function isLiquidityManagementPhase() external view returns (bool) {
        return _isLiquidityManagementPhase;
    }

    function setLiquidityManagementPhase(
        bool isLiquidityManagementPhase_
    ) external onlyLiquidityManager {
        _isLiquidityManagementPhase = isLiquidityManagementPhase_;
    }

    /************************************************************************/

    function withdrawStuckEth(uint256 amount) public onlyOwner {
        (bool success, ) = address(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function withdrawStuckEth() public onlyOwner {
        withdrawStuckEth(address(this).balance);
    }

    function withdrawStuckTokens(
        IERC20 token,
        uint256 amount
    ) public onlyOwner {
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function withdrawStuckTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        withdrawStuckTokens(token, balance);
    }

    function airdropHolders(
        address[] memory wallets,
        uint256[] memory amounts
    ) external onlyOwner {
        if (wallets.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            uint256 amount = amounts[i];
            _transfer(msg.sender, wallet, amount);
        }
    }

    /************************************************************************/

    function isExcludedFromMaxWallet(
        address account
    ) public view returns (bool) {
        return _isExcludedFromMaxWallet[account] || _isLeetPair[account];
    }

    function excludeFromMaxWallet(address account) external onlyOwner {
        _isExcludedFromMaxWallet[account] = true;
    }

    function includeInMaxWallet(address account) external onlyOwner {
        _isExcludedFromMaxWallet[account] = false;
    }

    function setMaxWalletEnabled(bool enabled) external onlyOwner {
        maxWalletEnabled = enabled;
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        maxWalletAmount = amount;
    }

    /************************************************************************/

    function addLeetPair(address _pair) external onlyOwner {
        _isLeetPair[_pair] = true;
        emit LeetPairAdded(_pair);
    }

    function removeLeetPair(address _pair) external onlyOwner {
        _isLeetPair[_pair] = false;
        emit LeetPairRemoved(_pair);
    }

    function excludeFromFee(address _account) external onlyOwner {
        isExcludedFromFee[_account] = true;
        emit AddressExcludedFromFees(_account);
    }

    function includeInFee(address _account) external onlyOwner {
        isExcludedFromFee[_account] = false;
        emit AddressIncludedInFees(_account);
    }

    function setFarmsFeeRecipient(address _account) external onlyOwner {
        if (_account == address(0)) {
            revert InvalidFeeRecipient();
        }
        farmsFeeRecipient = _account;
    }

    function setStakingFeeRecipient(address _account) external onlyOwner {
        if (_account == address(0)) {
            revert InvalidFeeRecipient();
        }
        stakingFeeRecipient = _account;
    }

    function setTreasuryFeeRecipient(address _account) external onlyOwner {
        if (_account == address(0)) {
            revert InvalidFeeRecipient();
        }

        treasuryFeeRecipient = _account;
    }

    function setBuyFees(
        uint256 _burnBuyFee,
        uint256 _farmsBuyFee,
        uint256 _stakingBuyFee,
        uint256 _treasuryBuyFee
    ) public onlyOwner {
        if (
            _burnBuyFee + _farmsBuyFee + _stakingBuyFee + _treasuryBuyFee >
            MAX_FEE
        ) {
            revert FeeTooHigh();
        }

        burnBuyFee = _burnBuyFee;
        farmsBuyFee = _farmsBuyFee;
        stakingBuyFee = _stakingBuyFee;
        treasuryBuyFee = _treasuryBuyFee;
        totalBuyFee = burnBuyFee + farmsBuyFee + stakingBuyFee + treasuryBuyFee;
    }

    function setSellFees(
        uint256 _burnSellFee,
        uint256 _farmsSellFee,
        uint256 _stakingSellFee,
        uint256 _treasurySellFee
    ) public onlyOwner {
        if (
            _burnSellFee + _farmsSellFee + _stakingSellFee + _treasurySellFee >
            MAX_FEE
        ) {
            revert FeeTooHigh();
        }

        burnSellFee = _burnSellFee;
        farmsSellFee = _farmsSellFee;
        stakingSellFee = _stakingSellFee;
        treasurySellFee = _treasurySellFee;
        totalSellFee =
            burnSellFee +
            farmsSellFee +
            stakingSellFee +
            treasurySellFee;
    }

    function setLiquidityManager(
        address _liquidityManager,
        bool _isManager
    ) public onlyOwner {
        isLiquidityManager[_liquidityManager] = _isManager;
    }

    function addWhitelistedFactory(address _factory) public onlyOwner {
        isWhitelistedFactory[_factory] = true;
    }

    function removeWhitelistedFactory(address _factory) public onlyOwner {
        isWhitelistedFactory[_factory] = false;
        _currentCacheVersion++;
    }

    function setIndirectSwapFeeEnabled(
        bool _indirectSwapFeeEnabled
    ) public onlyOwner {
        indirectSwapFeeEnabled = _indirectSwapFeeEnabled;
    }

    function enableTrading() public onlyOwner {
        if (tradingEnabled) revert TradingAlreadyEnabled();
        tradingEnabled = true;

        if (tradingEnabledTimestamp < block.timestamp) {
            tradingEnabledTimestamp = block.timestamp;
        }

        swappingFeesEnabled = true;
    }

    function setTradingEnabledTimestamp(uint256 _timestamp) public onlyOwner {
        if (tradingEnabled && tradingEnabledTimestamp <= block.timestamp) {
            revert TradingAlreadyEnabled();
        }

        if (tradingEnabled && _timestamp < block.timestamp) {
            revert TimestampIsInThePast();
        }

        tradingEnabledTimestamp = _timestamp;
    }

    function setPairAutoDetectionEnabled(
        bool _pairAutoDetectionEnabled
    ) public onlyOwner {
        pairAutoDetectionEnabled = _pairAutoDetectionEnabled;
    }

    function setSniperBuyFeeEnabled(
        bool _sniperBuyFeeEnabled
    ) public onlyOwner {
        sniperBuyFeeEnabled = _sniperBuyFeeEnabled;
    }

    function setSniperSellFeeEnabled(
        bool _sniperSellFeeEnabled
    ) public onlyOwner {
        sniperSellFeeEnabled = _sniperSellFeeEnabled;
    }

    function setSwapFeesAtAmount(uint256 _swapFeesAtAmount) public onlyOwner {
        swapFeesAtAmount = _swapFeesAtAmount;
    }

    function setMaxSwapFeesAmount(uint256 _maxSwapFeesAmount) public onlyOwner {
        maxSwapFeesAmount = _maxSwapFeesAmount;
    }

    function setSwappingFeesEnabled(
        bool _swappingFeesEnabled
    ) public onlyOwner {
        swappingFeesEnabled = _swappingFeesEnabled;
    }

    function setSwapFeesRouter(address _swapFeesRouter) public onlyOwner {
        swapFeesRouter = ILeetSwapV2Router01(_swapFeesRouter);
    }

    function setFeeDiscountOracle(IFeeDiscountOracle _oracle) public onlyOwner {
        feeDiscountOracle = _oracle;
    }

    function addBot(address account) public onlyOwner {
        isBot[account] = true;
    }

    function removeBot(address account) public onlyOwner {
        isBot[account] = false;
    }
}
