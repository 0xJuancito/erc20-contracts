// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./interfaces/UniswapInterface.sol";
import "./libraries/RFIFeeCalculator.sol";
import "./utils/Errors.sol";

/*
 * Por Token
 * Web: https://portoken.com 
 * Telegram: https://t.me/portumacommunity
 * Twitter: https://twitter.com/portumatoken
 * Instagram: https://www.instagram.com/portumatoken/
 * Linkedin: https://www.linkedin.com/company/portumatoken/
 * 
 * Total Supply: 10,000,000,000
 * Max Transaction Amount: 50,000,000 (0.5% of Total Supply)
 *
 *
 * first month sale conditions
 * Sell within 1 days  : %30 (%15 marketing, %5 Burn, %10 RFI) = Slippage Min: 43
 * Sell within 21 days : %20 (%10 marketing, %5 burn, %5 RFI) = Slippage Min: 25
 * Sell within 30 days : %10 (%7 marketing, %1 burn, %2 RFI) = Slippage Min: 11
 * sell after 30 days  : %5  (%4 marketing, %0.5 burn, %0.5 RFI) = Slippage Min: 6
 *
 * Ownership will be transferred to a Gnosis Multi Sig Wallet
 */

/// @title PorToken Token
/// @author WeCare Labs - https://wecarelabs.org
/// @notice Contract Has first month sell conditions by tiers defining the taken fee
contract PorToken is Initializable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using RFIFeeCalculator for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    
    // structs
    EnumerableSetUpgradeable.AddressSet internal rewardExcludedList;
    RFIFeeCalculator.taxTiers internal taxTiers;
    RFIFeeCalculator.feeData internal feeData;
    RFIFeeCalculator.transactionFee internal fees;

    uint256 internal constant MAX = type(uint256).max;

    uint256 internal _tTotal;
    uint256 internal _rTotal;

    uint256 internal _tFeeTotal;
    uint256 internal _maxTxAmount;

    uint256 internal _start_timestamp;
    address internal _marketingWallet;
    uint256 internal _marketingFeeCollected;
    uint256 internal _swapMarketingAtAmount; // = 1 * 10**6 * 10**_decimals;

    IUniswapV2Router02 internal uniswapV2Router;
    address internal uniswapV2Pair;
    bool internal tradingIsEnabled;

    // Reflection Owned
    mapping(address => uint256) internal _rOwned;
    // Token Owned
    mapping(address => uint256) internal _tOwned;
    // is address allowed to spend on behalf
    mapping(address => mapping(address => uint256)) internal _allowances;
    // is address excluded from fee taken
    mapping(address => bool) internal _isExcludedFromFee;
    // is address excluded from Maximum transaction amount
    mapping(address => bool) internal _isExcludedFromMaxTx;
    // is address Blacklisted?
    mapping(address => bool) internal _isBlacklisted;
    // store automatic market maker pairs.
    mapping(address => bool) internal automatedMarketMakerPairs;
    // check ıf swap in progress
    bool internal inSwap;

    bool internal locked;

    // modifiers
    modifier lockTheSwap {
        if (inSwap) revert noReentrancyOnSwap();

        inSwap = true;
        _;
        inSwap = false;
    }

    // Events
    event SetAutomatedMarketMakerPair(address indexed pair, bool value);
    event ResetStartTimestamp(uint256 newStartTimestamp);
    event SetBurnFee(uint256 newStartTimestamp);
    event SetHolderFee(uint256 newHolderFee);
    event SetMarketingFee(uint256 newMarketingFee);
    event SetMarketingWallet(address marketingWallet);
    event SetTeamWallet(address teamWalletAddress);
    // event SetSwapMarketingAtAmount(uint256 amount);
    event ExcludeFromReward(address account);
    event IncludeInReward(address account);
    // event CreateETHSwapPair(address routerAddress);
    event SetMaxTxAmount(uint256 amount);
    event ExcludeFromFee(address account);
    event IncludeInFee(address account);
    event SetTradingStatus(bool status);
    // event MarketingFeeSent(uint256 amount);
    event BlacklistStatusChanged(address indexed account, bool value);
    /// Since v1.0.5
    event AuthorizeUpgrade(address indexed newImplementation);
    event InitializeParams();
    event SetUniswapRouter(address indexed _addr);
    event SetUniswapPair(address indexed _addr);
    event WithdrawERC20(address indexed _recipient, address indexed _ERC20address, uint256 _amount, bool isSent);
    event TransferBalance(bool success);
    event MakeMM(address indexed addresses, bool _value);
    event ExcludeFromMaxTx(address indexed account, bool value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer external {
        __ERC20_init("Portuma", "POR");
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 1e10 * 10 ** decimals());

        __initializeParams();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {
        emit AuthorizeUpgrade(newImplementation);
    }

    receive() external payable {}

    // initialize the additional parameter on contract deploy
    function __initializeParams() initializer internal onlyOwner {
        _tTotal = super.totalSupply();
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[owner()] = _rTotal;

        _maxTxAmount = _tTotal * 50 / 1e4; //Max Transaction: 50 Million (0.5%)
        _swapMarketingAtAmount = 1 * 1e6 * 10**decimals();

        /// Standard Fees
        feeData = RFIFeeCalculator.feeData(0.5 * 1e2, 0.5 * 1e2, 4 * 1e2);

        taxTiers.time = [24, 504, 720];
        // 24 = 1 day, 168 = 7 days, 504 = 21 days, 720 = 30 days
        taxTiers.tax[0] = RFIFeeCalculator.feeData(5 * 1e2, 10 * 1e2, 15 * 1e2);
        taxTiers.tax[1] = RFIFeeCalculator.feeData(5 * 1e2, 5 * 1e2, 10 * 1e2);
        taxTiers.tax[2] = RFIFeeCalculator.feeData(1 * 1e2, 2 * 1e2, 7 * 1e2);

        _start_timestamp = block.timestamp;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        _isExcludedFromMaxTx[owner()] = true;

        rewardExcludedList.add(address(0xdead));
        rewardExcludedList.add(address(0));
        rewardExcludedList.add(address(this));

        /// Will be active after presale
        tradingIsEnabled = false;
        /// ran on v1.0.3 to fix reflection
        locked = false;

        emit InitializeParams();
    }

    /***********************************|
    |              Overrides            |
    |__________________________________*/
    function totalSupply() public view virtual override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        if (rewardExcludedList.contains(account)) return _tOwned[account];

        return tokenFromReflection(_rOwned[account]);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        if(account == address(0)) revert AddressIsZero(account);

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = balanceOf(account);
        if(amount > accountBalance) revert AmountExceedsAccountBalance();

        bool feeDeducted = rewardExcludedList.contains(account);
        uint256 rAmount = reflectionFromToken(amount, feeDeducted);
        _rTotal -= rAmount;
        _tTotal -= amount;
        
        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /***********************************|
    |           Write Functions         |
    |__________________________________*/
    function setMaxTxAmount(uint256 _maxAmount) external onlyOwner {
        if (_maxAmount > totalSupply()) revert MaxTransactionAmountExeeds(_maxAmount, totalSupply());

        _maxTxAmount = _maxAmount;
        emit SetMaxTxAmount(_maxAmount);
    }

    function excludeFromReward(address account) external onlyOwner {
        if (rewardExcludedList.contains(account)) revert AccountAlreadyExcludedFromReward(account);

        _excludeFromReward(account);
    }

    function includeInReward(address account) external onlyOwner {
        if (!rewardExcludedList.contains(account)) revert AccountAlreadyIncludedInReward(account);

        rewardExcludedList.remove(account);

        emit IncludeInReward(account);
    }

    function excludeFromFee(address account) external onlyOwner {
        if (_isExcludedFromFee[account]) revert AccountAlreadyExcludedFromFee(account);

        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account);
    }

    function includeInFee(address account) external onlyOwner {
        if (!_isExcludedFromFee[account]) revert AccountAlreadyIncludedInFee(account);

        _isExcludedFromFee[account] = false;
        emit IncludeInFee(account);
    }

    /// newStartTimestamp: in seconds
    function resetStartTimestamp(uint256 newStartTimestamp) external onlyOwner {
        _start_timestamp = newStartTimestamp;

        emit ResetStartTimestamp(newStartTimestamp);
    }

    /// newBurnFee: 100 = 1.00%
    function setBurnFee(uint256 newBurnFee) external onlyOwner {
        if (newBurnFee < 500) revert MaxLengthExeeds(500);
        feeData.burnFee = newBurnFee;

        emit SetBurnFee(newBurnFee);
    }

    /// newHolderFee: 100 = 1.00%
    function setHolderFee(uint256 newHolderFee) external onlyOwner {
        if (newHolderFee < 500) revert MaxLengthExeeds(500);
        feeData.holderFee = newHolderFee;

        emit SetHolderFee(newHolderFee);
    }

     /// newMarketingFee: 100 = 1.00%
    function setMarketingFee(uint256 newMarketingFee) external onlyOwner {
        if (newMarketingFee < 500) revert MaxLengthExeeds(500);
        feeData.marketingFee = newMarketingFee;

        emit SetMarketingFee(newMarketingFee);
    }

    function setMarketingWallet(address marketingWalletAddress) external onlyOwner {
        if (marketingWalletAddress == address(0)) revert AddressIsZero(marketingWalletAddress);
        
        _marketingWallet = marketingWalletAddress;
        _isExcludedFromFee[marketingWalletAddress] = true;

        emit SetMarketingWallet(marketingWalletAddress);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        if (automatedMarketMakerPairs[pair] == value) revert MarketMakerAlreadySet(pair, value);

        _setAutomatedMarketMakerPair(pair, value);
    }

    function setUniswapRouter(address _addr) external onlyOwner {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_addr);
        uniswapV2Router = _uniswapV2Router;

        emit SetUniswapRouter(_addr);
        _excludeFromReward(_addr);
    }

    function setUniswapPair(address _addr) external onlyOwner {
        if (_addr == address(0)) revert AddressIsZero(_addr);
        if (uniswapV2Pair == _addr) revert PairAlreadySet(_addr); 
        
        uniswapV2Pair = _addr;

        emit SetUniswapPair(_addr);
        _setAutomatedMarketMakerPair(uniswapV2Pair, true);
    }

    function setTradingIsEnabled(bool value) external onlyOwner {
        if (tradingIsEnabled == value) revert TradingStatusAlreadySet(value);

        tradingIsEnabled = value;
        emit SetTradingStatus(value);
    }

    function blacklistAddress(address account, bool value) external onlyOwner {
        if (_isBlacklisted[account] == value) revert BlaclistStatusAlreadySet(account, value);

        _isBlacklisted[account] = value;

        emit BlacklistStatusChanged(account, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) internal {
        if (automatedMarketMakerPairs[pair] == value) return;
        
        automatedMarketMakerPairs[pair] = value;

        _excludeFromReward(pair);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _excludeFromReward(address account) internal {
        if (!rewardExcludedList.contains(account)) {
            if (_rOwned[account] > 0) _tOwned[account] = tokenFromReflection(_rOwned[account]);

            rewardExcludedList.add(account);

            emit ExcludeFromReward(account);
        }
    }

    /// since 1.0.7
    function setExcludeFromMaxTx(address account, bool _value) external onlyOwner {
        if (_isExcludedFromMaxTx[account]) revert AccountAlreadyExcludedFromFee(account);

        _isExcludedFromMaxTx[account] = _value;

        emit ExcludeFromMaxTx(account, _value);
    }

    /***********************************|
    |            Read Functions         |
    |__________________________________*/
    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        if (rAmount > _rTotal) revert AmountExceedsTotalReflection(rAmount);

        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        if (tAmount > _tTotal) revert AmountExceedsTotalSupply(tAmount);
        uint256 tss = block.timestamp - _start_timestamp;
        
        RFIFeeCalculator.transactionFee memory f = tAmount.calculateFees(_getRate(), feeData, false, taxTiers, tss);
        if (!deductTransferFee) return f.rAmount;
        
        return f.rTransferAmount;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) external view returns (bool) {
        return rewardExcludedList.contains(account);
    }

    function getBurnFee() external view returns (uint256) {
        return feeData.burnFee;
    }

    function getHolderFee() external view returns (uint256) {
        return feeData.holderFee;
    }

    function getMarketingFee() external view returns (uint256) {
        return feeData.marketingFee;
    }

    function getTaxTiers() external view returns (uint256[] memory) {
        return taxTiers.time;
    }

    function getTradingStatus() external view returns (bool) {
        return tradingIsEnabled;
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _isBlacklisted[account];
    }

    function getMaxTxAmount() external view returns (uint256) {
        return _maxTxAmount;
    }

    function getStartTime() external view returns (uint256) {
        return _start_timestamp;
    }

    function _getRate() internal view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        
        return rSupply / tSupply;
    }

    // Get current supply for Reflection
    function _getCurrentSupply() internal view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        uint256 excludedLength = rewardExcludedList.length();
        uint256 i = 0;

        do {
            address excludedAddress = rewardExcludedList.at(i);
            if (_rOwned[excludedAddress] > rSupply || _tOwned[excludedAddress] > tSupply) return (_rTotal, _tTotal);

            rSupply -= _rOwned[excludedAddress];
            tSupply -= _tOwned[excludedAddress];

            i += 1;
        } while (i < excludedLength); // less Gas usage than for and while

        if (rSupply < _rTotal /_tTotal) return (_rTotal, _tTotal);

        return (rSupply, tSupply);
    }

    /***********************************|
   |          General Functions         |
   |__________________________________*/
    function getCurrentBurnFeeOnSale() external view returns (uint256 fee) {
        uint256 time_since_start = block.timestamp - _start_timestamp;
        return RFIFeeCalculator.getCurrentBurnFeeOnSale(time_since_start, taxTiers, feeData);
    }

    function getCurrentHolderFeeOnSale() external view returns (uint256 fee) {
        uint256 time_since_start = block.timestamp - _start_timestamp;
        return RFIFeeCalculator.getCurrentHolderFeeOnSale(time_since_start, taxTiers, feeData);
    }

    function getCurrentMarketingFeeOnSale() external view returns (uint256 fee) {
        uint256 time_since_start = block.timestamp - _start_timestamp;
        return RFIFeeCalculator.getCurrentMarketingFeeOnSale(time_since_start, taxTiers, feeData);
    }

    function calculateFee(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return (amount * fee) / 10**4;
    }
    
    /***********************************|
    |        Transfer Functions         |
    |__________________________________*/
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        _beforeTokenTransfer(sender, recipient, amount);

        _validateTransfer(sender, recipient, amount);

        // if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = true;
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) takeFee = false;

        bool isSell = false;
        if (sender != address(uniswapV2Router) && automatedMarketMakerPairs[recipient] && takeFee) isSell = true;

        _tokenTransfer(sender, recipient, amount, takeFee, isSell);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /// Validate Transaction Data
    function _validateTransfer(address sender, address recipient, uint256 amount) internal view {
        if (sender == address(0) || recipient == address(0)) revert SenderOrRecipientAddressIsZero(sender, recipient);
        if (_isBlacklisted[sender] || _isBlacklisted[recipient]) revert SenderOrRecipientBlacklisted(sender, recipient);
        if (amount <= 0) revert AmountIsZero();
        if (!tradingIsEnabled && (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient])) revert TradingNotStarted();

        if (!_isExcludedFromMaxTx[sender] && !_isExcludedFromMaxTx[recipient]) {
            if(amount > _maxTxAmount) revert MaxTransactionAmountExeeds(_maxTxAmount, amount);
        }

        uint256 curentSenderBalance = balanceOf(sender);
        if (amount > curentSenderBalance) revert InsufficientBalance(curentSenderBalance, amount);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee, bool isSell) internal {
        uint256 transferAmount = amount;
        uint256 currentRate = _getRate();

        if (takeFee) {
            uint256 tss = block.timestamp - _start_timestamp;
            RFIFeeCalculator.transactionFee memory f = amount.calculateFees(currentRate, feeData, isSell, taxTiers, tss);
            // Take Reflect Fee
            _takeReflectionFee(sender, recipient, f);
            _reflectTotal(f.rFee, f.tFee);

            if (f.tMarketing > 0) {
                _takeTransactionFee(_marketingWallet, f.tMarketing, f.currentRate);
                emit Transfer(sender, _marketingWallet, f.tMarketing);
            }

            if (f.tBurn > 0) {
                _rTotal -= f.rBurn;
                _tTotal -= f.tBurn;

                emit Transfer(sender, address(0), f.tBurn);
            }

            transferAmount = f.tTransferAmount;
        } else {
            uint256 reflectionAmount = transferAmount * currentRate;
            RFIFeeCalculator.transactionFee memory nofee = RFIFeeCalculator.transactionFee(
                reflectionAmount, reflectionAmount, 0, 0, 0, transferAmount, transferAmount, 0, 0, 0, currentRate
            );
            _takeReflectionFee(sender, recipient, nofee);
        }

        emit Transfer(sender, recipient, transferAmount);
    }

    function _takeReflectionFee(address sender, address recipient, RFIFeeCalculator.transactionFee memory f) internal {
        _rOwned[sender] -= f.rAmount;
        _rOwned[recipient] += f.rTransferAmount;

        if (rewardExcludedList.contains(sender)) _tOwned[sender] -= f.tAmount;
        if (rewardExcludedList.contains(recipient)) _tOwned[recipient] += f.tTransferAmount;
    }

    function _takeTransactionFee(address to, uint256 tAmount, uint256 currentRate) internal {
        uint256 rAmount = tAmount * currentRate;
        _rOwned[to] += rAmount;

        if (rewardExcludedList.contains(to)) _tOwned[to] += tAmount;
    }

    function _reflectTotal(uint256 rFee, uint256 tFee) internal {
        _rTotal -= rFee;
        _tFeeTotal += tFee;
    }

    /***********************************|
    |            External Calls         |
    |__________________________________*/
    // Send ERC20 Tokens to Multisig wallet
    function withdrawERC20(address _recipient, address _ERC20address, uint256 _amount) external onlyOwner returns (bool) {
        if (_ERC20address == address(this)) revert CannotTransferContractTokens();
        bool isSent = IERC20Upgradeable(_ERC20address).transfer(_recipient, _amount);

        emit WithdrawERC20(_recipient, _ERC20address, _amount, isSent);

        return isSent;
    }

    // Send Contract BNB/ETH Balance to Marketing wallet
    function transferBalance() external onlyOwner returns (bool) {
        (bool success,) = address(_marketingWallet).call{value: address(this).balance}("");
        
        emit TransferBalance(success);

        return success;
    }

    function withdrawContractTokens() external onlyOwner returns (bool) {
        uint256 contractBalance = balanceOf(address(this));
        uint256 currentRate = _getRate();

        if (contractBalance > 0) {
            uint256 rAmount = contractBalance * currentRate;
            _rOwned[_marketingWallet] += rAmount;

            if (rewardExcludedList.contains(_marketingWallet)) _tOwned[_marketingWallet] += contractBalance;

            _tOwned[address(this)] = 0;

            emit Transfer(address(this), _marketingWallet, contractBalance);
        }

        return true;
    }

    function multiTransfer(address[] calldata addresses, uint256[] calldata tokens) external onlyOwner {
        address from = msg.sender;
        uint256 addrLength = addresses.length;
        uint256 tokenLength = tokens.length;
        if (addrLength > 100) revert MaxLengthExeeds(100);
        if (addrLength != tokenLength) revert MismatchLength(addrLength, tokenLength);

        uint256 senderBalance = balanceOf(from);
        uint256 totalToken = 0;
        for (uint i = 0; i < addrLength; i++) {
            totalToken += tokens[i];

            if (totalToken >= senderBalance) revert AmountExceedsAccountBalance();
        }

        for (uint i = 0; i < addrLength; i++) {
            uint256 currentRate = _getRate();
            uint256 transferAmount = tokens[i];
            uint256 reflectionAmount = transferAmount * currentRate;
            
            RFIFeeCalculator.transactionFee memory nofee = RFIFeeCalculator.transactionFee(
                reflectionAmount, reflectionAmount, 0, 0, 0, transferAmount, transferAmount, 0, 0, 0, currentRate
            );

            _takeReflectionFee(from, addresses[i], nofee);
            emit Transfer(from, addresses[i], transferAmount);
        }
    }

    function makeMM(address[] calldata addresses, bool _value) external onlyOwner {
        uint256 addrLength = addresses.length;
        if (addrLength > 50) revert MaxLengthExeeds(50);

        for (uint i = 0; i < addrLength; i++) {
            _isExcludedFromFee[addresses[i]] = _value;
            emit MakeMM(addresses[i], _value);
        }
    }

    function isLocked() external view returns (bool) {
        return locked;
    }

    function getTOwned(address account) external view returns (uint256) {
        return _tOwned[account];
    }

    function getROwned(address account) external view returns (uint256) {
        return _rOwned[account];
    }

    /// since 1.0.5
    /// added for extending and seperating the buy and sell fees
    /// until new fee system applied
    function extendSellFeePeriod() external onlyOwner {
        // 24 = 1 day, 168 = 7 days, 504 = 21 days, 720 = 30 days, 1440 = 60 days, 8640 = 360 days
        taxTiers.time = [24, 504, 720, 8640];

        taxTiers.tax[3] = RFIFeeCalculator.feeData(0.5 * 1e2, 0.5 * 1e2, 4 * 1e2);
    }

    // Current Version of the implementation
    function version() external pure virtual returns (string memory) {
        return '1.0.7';
    }
}