// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

// openzeppelin
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./DoubleQueueModified.sol";

// interface
import "./interfaces/IFeeManager.sol";
import "./interfaces/IOpenEdenVault.sol";
import "./interfaces/IKycManager.sol";
import "./interfaces/IPriceFeed.sol";
import "./Controller.sol";

/// @title  OpenEdenVaultV2
/// @author OpenEden
/// @notice This contract is the main contract for OpenEden T-Bills
contract OpenEdenVaultV2 is
    ERC20Upgradeable,
    OwnableUpgradeable,
    IOpenEdenVault,
    UUPSUpgradeable
{
    using DoubleQueueModified for DoubleQueueModified.BytesDeque;
    using MathUpgradeable for uint256;

    // indicate the fixed bps unit, 1e4, will be used for calculating the fee and the depeg threshold
    uint256 public constant BPSUNIT = 1e4;

    // indicates the fixed usdc price, 1 usdc = 1e8
    uint256 public constant ONE = 1e8;

    // chainlink usdc price feed depg threshold, 100 stands for 1%
    uint256 public maxDepeg;

    // chainlink usdc price feed max time delay, 24 hours
    uint256 public maxTimeDelay;

    // tbill decimal scale factor,
    uint256 public tbillDecimalScaleFactor;

    // underlying token, usdc
    IERC20MetadataUpgradeable public underlying;

    // controller contract, pause/unpause deposit and withdraw
    Controller public controller;

    // used to maintain the vault
    address public operator;

    // tbill price feed, used to calculate the price of tbill
    IPriceFeed public tbillUsdPriceFeed;

    // usdc price feed, used to calculate the price of usdc
    IPriceFeed public usdcUsdPriceFeed;

    // address to receive service fee
    address public oplTreasury;

    // address to receive underlying token
    address public treasury;

    // address to receive unexpected quarantine tokens
    address public qTreasury;

    // fee manager contract, used to calculate the fee
    IFeeManager public feeManager;

    // kyc manager contract, used to check the kyc status
    IKycManager public kycManager;

    // management fee, will be charged when user deposit/redeem(processWithdrawalQueue)
    uint256 public unClaimedFee;

    // current epoch, will be updated when updateEpoch
    uint256 public epoch;

    // current weekend deposit amount, will be used to calculate the weekend deposit limit
    uint256 public currWeekendDeposit;

    // current weekend withdraw amount, will be used to calculate the weekend withdraw limit
    uint256 public currWeekendWithdraw;

    // indicate whether it is weekend, will be updated when updateEpoch
    bool public isWeekend;

    // withdraw queue data structure
    DoubleQueueModified.BytesDeque private withdrawalQueue;

    // indicate whether the user has deposited before
    mapping(address => bool) private firstDepositMap;

    // deposit amount map, will be used to calculate the deposit limit
    mapping(uint256 => uint256) private depositAmountMap;

    // withdraw amount map, will be used to calculate the withdraw limit
    mapping(uint256 => uint256) private withdrawAmountMap;

    // useded to query the withdraw shares of the user that in the queue
    mapping(address => uint256) private withdrawalInfo;

    // only operator can call this function
    modifier onlyOperator() {
        require(_msgSender() == operator, "permission denied");
        _;
    }

    // check whether the usdc price is ont depeg and the price is not stale
    // will be used in deposit/redeem/processWithdrawalQueue
    // will reject if not meet the requirement
    modifier onlyValidPrice() {
        (, int256 answer1, , uint256 updateAt, ) = usdcUsdPriceFeed
            .latestRoundData();

        require(
            block.timestamp - updateAt <= maxTimeDelay,
            "stale usdc answer!"
        );
        require(answer1 > 0, "should gt 0");
        uint256 answer = uint256(answer1);

        uint256 numerator = ONE > answer ? ONE - answer : answer - ONE;
        uint256 denominator = (ONE + answer) / 2;

        uint256 depeg = (numerator * ONE) / denominator;
        uint256 max = (maxDepeg * ONE) / BPSUNIT;
        require(depeg <= max, "usdc and usd depeg!");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract and sets the initial state variables. This is called by the proxy and should only be called once.
     * @dev This function is intended for setting initial values for the contract's state variables. Ensure the provided holders have KYC granted before deploying this contract.
     * @param _underlying The underlying ERC20 token for the vault.
     * @param _controller Reference to the associated Controller contract.
     * @param _operator Address of the operator for the vault.
     * @param _tbillUsdPriceFeed Reference to the T-bill to USD price feed contract.
     * @param _usdcUsdPriceFeed Reference to the USDC to USD price feed contract.
     * @param _oplTreasury Address of the OPL treasury.
     * @param _treasury Address of the main treasury.
     * @param _feeManager Reference to the associated Fee Manager contract.
     * @param _kycManager Reference to the KYC Manager contract.
     * @param _holders Array of addresses representing initial holders.
     * @param _shares Array of shares corresponding to the initial holders.
     */
    function initialize(
        IERC20MetadataUpgradeable _underlying,
        Controller _controller,
        address _operator,
        IPriceFeed _tbillUsdPriceFeed,
        IPriceFeed _usdcUsdPriceFeed,
        address _oplTreasury,
        address _treasury,
        IFeeManager _feeManager,
        IKycManager _kycManager,
        address[] memory _holders,
        uint256[] memory _shares
    ) external initializer {
        __ERC20_init("OpenEden T-Bills", "TBILL");
        __Ownable_init();
        __UUPSUpgradeable_init();

        __vault_init(_underlying);
        controller = _controller;
        operator = _operator;
        tbillUsdPriceFeed = _tbillUsdPriceFeed;
        usdcUsdPriceFeed = _usdcUsdPriceFeed;

        oplTreasury = _oplTreasury;
        treasury = _treasury;
        feeManager = _feeManager;
        kycManager = _kycManager;

        //[note]: should pre grant kyc before deloy vault v2 contract
        _preMint(_holders, _shares);
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice deposit underlying to this contract and mint shares to the receiver
     * @dev will charge fees before mint, and the underlying will be transfered from the sender to Treasury
     * @param _assets a parameter just like in doxygen (must be followed by parameter name)
     * @param _receiver Documents the return variables of a contract’s function state variable
     */
    function deposit(
        uint256 _assets,
        address _receiver
    ) external onlyValidPrice {
        controller.requireNotPausedDeposit();

        address sender = _msgSender();
        _validateKyc(sender, _receiver);

        validateDeposit(_assets);
        _processDeposit(sender, _receiver, _assets);
    }

    /**
     * @notice redeem shares to underlying
     * @dev all withdraw requests will be put into a queue, and will be processed after get the sufficient assets
     * @param _shares the amount of shares to redeem
     * @param _receiver the address to receive the underlying
     */
    function redeem(
        uint256 _shares,
        address _receiver
    ) external onlyValidPrice {
        controller.requireNotPausedWithdraw();

        address sender = _msgSender();
        _validateKyc(sender, _receiver);

        uint256 assets = _convertToAssets(_shares);
        if (isWeekend) {
            currWeekendWithdraw += assets;
        }

        validateWithdraw(assets);
        _processWithdraw(sender, _receiver, _shares);
    }

    /**
     * @notice cancel the first withdraw request in the queue, only operator can call this function
     * @dev will transfer the shares to qTreasury
     * @param _len the length of the cancel queue
     */
    function cancel(uint256 _len) external onlyOperator {
        require(_len > 0 && _len <= withdrawalQueue.length(), "invalid len");
        controller.requireNotPausedWithdraw();
        uint256 totalShares;

        while (_len > 0) {
            bytes memory data = withdrawalQueue.popFront();

            (
                address sender,
                address receiver,
                uint256 shares,
                bytes32 prevId
            ) = _decodeData(data);

            // only cancel the user who is banned
            // if a user is banned by usdc, we will ban him as well, then prform the cancel
            require(kycManager.isBanned(receiver), "user is not banned");
            unchecked {
                totalShares += shares;
                _len--;
            }
            _transfer(address(this), qTreasury, shares);
            emit ProcessRedeemCancel(sender, receiver, shares, prevId);
        }
        emit Cancel(_len, totalShares);
    }

    /**
     * @dev transfer underlying from vault to treasury, only operator can call this function
     * @param _amt the amount of the token to transfer
     */
    function offRamp(uint256 _amt) external onlyOperator {
        _offRamp(address(underlying), treasury, _amt);
        emit OffRamp(treasury, _amt);
    }

    /**
     * @dev transfer unexpected tokens from vault to qtreasury, only operator can call this function
     * @param _token the address of the token to transfer
     * @param _amt the amount of the token to transfer
     */
    function offRampQ(address _token, uint256 _amt) external onlyOperator {
        require(_token != address(this), "not allowed to move tbill!");
        _offRamp(_token, qTreasury, _amt);
        emit OffRampQ(qTreasury, _amt);
    }

    /**
     * @dev process the withdrawal queue, only operator can call this function
     * @param _len the length of the queue to process, 0 means process all
     */
    function processWithdrawalQueue(
        uint _len
    ) external onlyValidPrice onlyOperator {
        uint256 length = withdrawalQueue.length();
        require(length > 0, "empty queue!");
        require(_len <= length, "invalid len!");
        if (_len == 0) _len = length;

        uint256 totalWithdrawAssets;
        uint256 totalBurnShares;
        uint256 totalFees;

        for (uint count = 0; count < _len; ) {
            bytes memory data = withdrawalQueue.front();
            (
                address sender,
                address receiver,
                uint256 shares,
                bytes32 prevId
            ) = _decodeData(data);

            _validateKyc(sender, receiver);
            uint256 assets = _convertToAssets(shares);

            // 1. will not process the queue if the assets is not enough
            // 2. will process the queue by sequence, so if the first one is not enough, the rest will not be handled
            if (assets > onchainAssets()) {
                return;
            }

            // will calculate the fee based on the lastest fee rate, not the fee rate when the user redeem
            // if not enough, will revert
            (uint256 txFee, uint256 trimmedAssets) = _chargeFees(
                address(this),
                assets
            );

            withdrawalQueue.popFront();
            unchecked {
                ++count;
                totalWithdrawAssets += trimmedAssets;
                totalBurnShares += shares;
                totalFees += txFee;
                withdrawalInfo[receiver] -= shares;
            }

            _withdraw(
                address(this),
                receiver,
                address(this),
                trimmedAssets,
                shares
            );

            emit ProcessWithdraw(
                sender,
                receiver,
                assets,
                shares,
                trimmedAssets,
                shares,
                txFee,
                prevId,
                oplTreasury
            );
        }
        emit ProcessWithdrawalQueue(
            totalWithdrawAssets,
            totalBurnShares,
            totalFees
        );
    }

    /**
     * @dev will update the closeNavPrice, currently set to 8am sgt, 00:00 utc
     * @param _isWeekend whether it is weekend
     */
    function updateEpoch(bool _isWeekend) external onlyOperator {
        epoch++;
        isWeekend = _isWeekend;

        uint256 feeRate = feeManager.getManagementFeeRate();
        unClaimedFee += _calServiceFee(totalAssets(), feeRate);

        if (
            !isWeekend && (currWeekendDeposit != 0 || currWeekendWithdraw != 0)
        ) {
            currWeekendDeposit = 0;
            currWeekendWithdraw = 0;
        }
        emit UpdateEpoch(unClaimedFee, epoch, isWeekend);
    }

    /**
     * @notice Set the flag indicating whether it's a weekend or not.
     * @dev Can only be called by the operator.
     * @param _isWeekend Boolean value indicating weekend status.
     */
    function setWeekendFlag(bool _isWeekend) external onlyOperator {
        isWeekend = _isWeekend;
        emit SetWeekendFlag(_isWeekend);
    }

    /**
     * @notice Claim a specified amount of service fees.
     * @dev Can only be called by the operator.
     * @param _amt Amount of service fees to be claimed.
     */
    function claimServiceFee(uint256 _amt) external onlyOperator {
        require(oplTreasury != address(0), "invalid opl address");
        unClaimedFee -= _amt;

        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(underlying),
            oplTreasury,
            _amt
        );
        emit ClaimServiceFee(oplTreasury, _amt);
    }

    /**
     * @notice Update the address that receives the service fee.
     * @dev Can only be called by the contract owner.
     * @param _opl Address of the new treasury.
     */
    function setOplTreasury(address _opl) external onlyOwner {
        require(_opl != address(0), "zero address!");
        oplTreasury = _opl;
        emit SetOplTreasury(_opl);
    }

    /**
     * @notice Update the Fee Manager address.
     * @dev Can only be called by the contract owner.
     * @param _feeManager Address of the new Fee Manager.
     */
    function setFeeManager(address _feeManager) external onlyOwner {
        require(_feeManager != address(0), "zero address!");
        feeManager = IFeeManager(_feeManager);
        emit SetFeeManager(_feeManager);
    }

    /**
     * @notice Update the KYC Manager address.
     * @dev Can only be called by the contract owner.
     * @param _kycManager Address of the new KYC Manager.
     */
    function setKycManager(address _kycManager) external onlyOwner {
        require(_kycManager != address(0), "zero address!");
        kycManager = IKycManager(_kycManager);
        emit SetKycManager(_kycManager);
    }

    /**
     * @notice Set a new operator for the contract.
     * @dev Can only be called by the contract owner.
     * @param _operator Address of the new operator.
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "zero address!");
        operator = _operator;
        emit SetOperator(_operator);
    }

    /**
     * @notice Set a new price feed for USDC/USD.
     * @dev Can only be called by the contract owner.
     * @param _priceFeed Address of the new price feed.
     */
    function setUsdcPriceFeed(address _priceFeed) external onlyOwner {
        require(_priceFeed != address(0), "zero address!");
        usdcUsdPriceFeed = IPriceFeed(_priceFeed);
        emit SetUsdcPriceFeed(_priceFeed);
    }

    /**
     * @notice Set a new price feed for TBill/USD.
     * @dev Can only be called by the contract owner.
     * @param _priceFeed Address of the new price feed.
     */
    function setTBillPriceFeed(address _priceFeed) external onlyOwner {
        require(_priceFeed != address(0), "zero address!");
        tbillUsdPriceFeed = IPriceFeed(_priceFeed);
        emit SetTBillPriceFeed(_priceFeed);
    }

    /**
     * @notice Update the Controller address.
     * @dev Can only be called by the contract owner.
     * @param _controller Address of the new Controller.
     */
    function setController(address _controller) external onlyOwner {
        require(_controller != address(0), "zero address!");
        controller = Controller(_controller);
        emit SetController(_controller);
    }

    /**
     * @notice Set a new address to receive the service fee.
     * @dev Can only be called by the contract owner.
     * @param _treasury Address of the new treasury.
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero address!");
        treasury = _treasury;
        emit UpdateTreasury(_treasury);
    }

    /**
     * @notice Set a new address to receive the Q-treasury fee.
     * @dev Can only be called by the contract owner.
     * @param _qTreasury Address of the new Q-treasury.
     */
    function setQTreasury(address _qTreasury) external onlyOwner {
        require(_qTreasury != address(0), "zero address!");
        qTreasury = _qTreasury;
        emit UpdateQTreasury(_qTreasury);
    }

    /**
     * @notice Set a maximum depeg for USDC and USD.
     * @dev Can only be called by the contract owner.
     * @param _max Maximum depeg value, 100 indicates 1%.
     */
    function setMaxDepeg(uint256 _max) external onlyOwner {
        maxDepeg = _max;
        emit SetMaxDepeg(_max);
    }

    /**
     * @notice Set a maximum time delay for USDC price feed.
     * @dev Can only be called by the contract owner.
     * @param _maxTimeDelay Maximum time delay value, in seconds.
     */
    function setMaxTimeDelay(uint256 _maxTimeDelay) external onlyOwner {
        maxTimeDelay = _maxTimeDelay;
        emit SetMaxTimeDelay(_maxTimeDelay);
    }

    /**
     * @notice Upgrade to a new implementation address.
     * @dev Can only be called by the contract owner.
     * @param newImpl Address of the new vault implementation
     */
    function upgradeTo(address newImpl) external override onlyOwner {
        _authorizeUpgrade(newImpl);
        _upgradeToAndCallUUPS(newImpl, new bytes(0), false);
    }

    /**
     * @notice Retrieve withdrawal queue information for a given index.
     * @param _index Index to retrieve data from.
     * @return sender The sender's address.
     * @return receiver The receiver's address.
     * @return shares The number of shares.
     * @return id The ID associated with the withdrawal.
     */
    function getWithdrawalQueueInfo(
        uint256 _index
    )
        external
        view
        returns (address sender, address receiver, uint256 shares, bytes32 id)
    {
        if (withdrawalQueue.empty() || _index > withdrawalQueue.length() - 1) {
            return (address(0), address(0), 0, 0x0);
        }

        bytes memory data = bytes(withdrawalQueue.at(_index));
        (sender, receiver, shares, id) = _decodeData(data);
    }

    /**
     * @notice Retrieve withdrawal information for a specific user that is in the queue.
     * @param _user Address of the user.
     * @return shares Number of shares associated with the user.
     */
    function getWithdrawalUserInfo(
        address _user
    ) external view returns (uint256 shares) {
        return withdrawalInfo[_user];
    }

    /**
     * @notice Retrieve the total shares of withdrawals, the quarantine tbills are not included.
     * @return shares Total number of withdrawal shares.
     */
    function getWithdrawalTotalShares() external view returns (uint256 shares) {
        return balanceOf(address(this));
    }

    /**
     * @notice Retrieve the length of the withdrawal queue.
     * @return Length of the withdrawal queue.
     */
    function getWithdrawalQueueLength() external view returns (uint256) {
        return withdrawalQueue.length();
    }

    //////////////////////////////////////////////////////////////
    //                        PUBLIC FUNCTIONS                   //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Compute the transaction fee for a given asset amount, minimum fee is 25usdc by default
     * @param _assets Asset amount to compute fee for.
     * @return Calculated transaction fee.
     */
    function txsFee(uint256 _assets) public view returns (uint256) {
        uint256 bpsTxsFee = (_assets * txsFeeRate()) / BPSUNIT;
        uint256 minTxsFee = feeManager.getMinTxsFee();
        return bpsTxsFee > minTxsFee ? bpsTxsFee : minTxsFee;
    }

    /**
     * @notice Validate the deposit for a given asset amount.
     * will check the min/max deposit amount and the weekend deposit limit
     * @param _assets Asset amount to validate deposit for.
     * @return true if deposit is valid, false otherwise.
     */
    function validateDeposit(uint256 _assets) public view returns (bool) {
        if (isWeekend) {
            validWeekendDepositAmount(_assets);
        }
        (uint256 minDeposit, uint256 maxDeposit) = feeManager
            .getMinMaxDeposit();
        require(_assets >= minDeposit, "amount should gt minimum deposit");

        (uint256 depositAmt, uint256 withdrawAmt, uint256 gap) = getEpochInfo(
            epoch
        );

        if (depositAmt >= withdrawAmt) {
            require(_assets <= maxDeposit - gap, "deposit too much 1");
        } else {
            require(_assets <= maxDeposit + gap, "deposit too much 2");
        }
        return true;
    }

    /**
     * @notice Validate the withdrawal for a given asset amount
     * will check the min/max withdrawal amount and the weekend withdraw limit
     * @param _assets Asset amount to validate withdrawal for.
     * @return true if withdrawal is valid, false otherwise.
     */
    function validateWithdraw(uint256 _assets) public view returns (bool) {
        (uint256 minWithdraw, uint256 maxWithdraw) = feeManager
            .getMinMaxWithdraw();
        (uint256 depositAmt, uint256 withdrawAmt, uint256 gap) = getEpochInfo(
            epoch
        );

        require(_assets >= minWithdraw, "amount should gt minimum withdraw");

        if (depositAmt >= withdrawAmt) {
            require(_assets <= maxWithdraw + gap, "withdraw too much 1");
        } else {
            require(_assets <= maxWithdraw - gap, "withdraw too much 2");
        }
        return true;
    }

    /**
     * @notice Validate weekend deposit amount for a given asset amount.
     * @param _assets Asset amount to validate for weekend deposit.
     * @return true if weekend deposit is valid, false otherwise.
     */
    function validWeekendDepositAmount(
        uint256 _assets
    ) public view returns (bool) {
        uint256 totalAssetsAmt = totalAssets();
        (uint256 pct1, uint256 pct2) = feeManager.getMaxWeekendDepositPct();
        uint256 maxWeekendDeposit = (totalAssetsAmt * pct1) / BPSUNIT; // per tx
        require(_assets <= maxWeekendDeposit, "invalid deposit amount");

        (uint256 netAggregated, bool flag) = getGap(
            currWeekendDeposit + _assets,
            currWeekendWithdraw
        );

        if (flag) {
            uint256 netAllowed = (totalAssetsAmt * pct2) / BPSUNIT;
            require(netAggregated <= netAllowed, "reach out weekend limit");
        }
        return true;
    }

    /**
     * @notice Retrieve epoch information for a given epoch.
     * @param _epoch Epoch to retrieve information for.
     * @return depositAmt Total deposit amount for the epoch.
     * @return withdrawAmt Total withdrawal amount for the epoch.
     * @return gap Gap between deposit and withdrawal amounts.
     */
    function getEpochInfo(
        uint256 _epoch
    )
        public
        view
        returns (uint256 depositAmt, uint256 withdrawAmt, uint256 gap)
    {
        depositAmt = depositAmountMap[_epoch];
        withdrawAmt = withdrawAmountMap[_epoch];

        (gap, ) = getGap(depositAmt, withdrawAmt);
        return (depositAmt, withdrawAmt, gap);
    }

    /**
     * @notice Retrieve the on-chain assets amount.
     * @return assetAmt Amount of on-chain assets.
     */
    function onchainAssets() public view returns (uint256 assetAmt) {
        return IERC20Upgradeable(underlying).balanceOf(address(this));
    }

    /**
     * @notice Calculates the total assets in USDC by multiplying the current total supply with the tbillUsdc rate.
     * @return assetAmt The total assets in USDC.
     */
    function totalAssets() public view returns (uint256 assetAmt) {
        assetAmt = (totalSupply() * tbillUsdcRate()) / tbillDecimalScaleFactor;
    }

    /**
     * @notice Converts the T-bill to USDC rate by dividing the tbill/usd rate by usdc/usd rate.
     * @return rate The conversion rate of T-bill to USDC.
     */
    function tbillUsdcRate() public view returns (uint256 rate) {
        uint256 tbillUsdPrice = tbillUsdPriceFeed.latestAnswer();
        rate = (tbillUsdPrice * tbillDecimalScaleFactor) / ONE;
    }

    /**
     * @notice Fetches the decimal places of the tbill token, same as the underlying token.
     * @return The number of decimal places.
     */
    function decimals() public view virtual override returns (uint8) {
        return underlying.decimals();
    }

    /**
     * @notice Gives a preview of the shares equivalent for the given assets.
     * @param _assets Amount of assets.
     * @return Equivalent shares for the given assets.
     */
    function previewDeposit(uint256 _assets) public view returns (uint256) {
        return _convertToShares(_assets);
    }

    /**
     * @notice Gives a preview of the assets equivalent for the given shares.
     * @param _shares Amount of shares.
     * @return Equivalent assets for the given shares.
     */
    function previewRedeem(
        uint256 _shares
    ) public view virtual returns (uint256) {
        return _convertToAssets(_shares);
    }

    /**
     * @notice Fetches the transaction fee rate based on whether it's weekend or not.
     * @return The transaction fee rate.
     */
    function txsFeeRate() public view returns (uint256) {
        return
            isWeekend
                ? feeManager.getTxFeeWeekend()
                : feeManager.getTxFeeWeekday();
    }

    /**
     * @notice Checks if the investor has made a deposit before.
     * @param investor The address of the investor.
     * @return true if the investor has made a deposit before, false otherwise.
     */
    function hasDepositBefore(address investor) public view returns (bool) {
        return firstDepositMap[investor];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles the deposit logic, converting assets into shares, managing fees, and updating relevant state.
     * @param _sender The sender of the assets.
     * @param _receiver The receiver of the shares.
     * @param _assets Amount of assets being deposited.
     */
    function _processDeposit(
        address _sender,
        address _receiver,
        uint256 _assets
    ) internal {
        (uint256 txFee, uint256 trimmedAssets) = _chargeFees(_sender, _assets);
        uint256 shares = _convertToShares(trimmedAssets);

        if (!hasDepositBefore(_sender)) {
            require(
                _assets >= feeManager.getFirstDeposit(),
                "amount should gt first deposit"
            );
            _setFirstDeposit(_sender);
        }

        depositAmountMap[epoch] += trimmedAssets;
        if (isWeekend) {
            currWeekendDeposit += trimmedAssets;
        }

        _deposit(_sender, _receiver, trimmedAssets, shares, treasury);
        emit ProcessDeposit(
            _sender,
            _receiver,
            _assets,
            shares,
            txFee,
            oplTreasury,
            treasury
        );
    }

    /**
     * @dev Internal function to charge transaction fees.
     * @param _assetsFrom The address of the asset's origin.
     * @param _assetsAmt The amount of assets to be charged.
     * @return txFee The calculated transaction fee.
     * @return trimmedAssets The assets amount after subtracting the transaction fee.
     */
    function _chargeFees(
        address _assetsFrom,
        uint256 _assetsAmt
    ) internal returns (uint256, uint256) {
        uint256 txFee = txsFee(_assetsAmt);
        uint256 trimmedAssets = _assetsAmt - txFee;
        address assetsTo = oplTreasury;

        // this is a general deposit, will charge from EOA
        if (_assetsFrom != address(this)) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(underlying),
                _assetsFrom,
                assetsTo,
                txFee
            );
        } else {
            // this is a withdraw queue, will charege from address(this)
            SafeERC20Upgradeable.safeTransfer(
                IERC20Upgradeable(underlying),
                assetsTo,
                txFee
            );
        }

        return (txFee, trimmedAssets);
    }

    /**
     * @dev Internal function to process a withdrawal.
     * @param _sender Address of the sender.
     * @param _receiver Address of the receiver.
     * @param _shares Number of shares to withdraw.
     */
    function _processWithdraw(
        address _sender,
        address _receiver,
        uint256 _shares
    ) internal {
        withdrawAmountMap[epoch] += _convertToAssets(_shares);
        withdrawalInfo[_receiver] += _shares;

        bytes32 id = keccak256(
            abi.encode(
                _sender,
                _receiver,
                _shares,
                block.timestamp,
                withdrawalQueue.length()
            )
        );

        bytes memory data = abi.encode(_sender, _receiver, _shares, id);
        withdrawalQueue.pushBack(data);

        _transfer(_sender, address(this), _shares);
        emit AddToWithdrawalQueue(_sender, _receiver, _shares, id);
    }

    /**
     * @dev Converts the number of shares to asset amount.
     * @param _shares Number of shares to convert.
     * @return assets Equivalent asset amount.
     */
    function _convertToAssets(
        uint256 _shares
    ) internal view returns (uint256 assets) {
        assets = _shares.mulDiv(tbillUsdcRate(), tbillDecimalScaleFactor);
    }

    /**
     * @dev Converts asset amount to the equivalent number of shares.
     * @param _assets Asset amount to convert.
     * @return shares Equivalent number of shares.
     */
    function _convertToShares(
        uint256 _assets
    ) internal view returns (uint256 shares) {
        shares = _assets.mulDiv(tbillDecimalScaleFactor, tbillUsdcRate());
    }

    /**
     * @dev Off-ramp function to transfer the specified token amount.
     * @param _token The token to transfer.
     * @param _to Destination address.
     * @param _amt Amount of token to transfer.
     */
    function _offRamp(address _token, address _to, uint256 _amt) internal {
        require(_to != address(0), "invalid _to address!");
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amt);
    }

    /**
     * @dev Hook that gets called before tokens are transferred. Used for KYC validations.
     * @param _from Sender address.
     * @param _to Receiver address.
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256
    ) internal view override {
        /* _mint() or _burn() will set one of to address(0)
         *  no need to limit for these scenarios
         */
        if (_from == address(0) || _to == address(0)) {
            return;
        }
        _validateKyc(_from, _to);
    }

    /**
     * @dev Authorizes a new implementation upgrade.
     * @param _newImpl Address of the new implementation.
     */
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}

    /**
     * @dev Calculate service fee for given asset amount.
     * @param _assets Asset amount.
     * @param _rate Rate for calculating service fee.
     * @return fee Calculated service fee.
     */
    function _calServiceFee(
        uint256 _assets,
        uint256 _rate
    ) internal pure returns (uint256 fee) {
        fee = (_assets * _rate) / (365 * BPSUNIT);
    }

    /**
     * @dev Pre-mints shares for specified holders during initialization, for V1 migration
     * @param _holders List of holder addresses.
     * @param _shares List of share amounts to mint for corresponding holders.
     */
    function _preMint(
        address[] memory _holders,
        uint256[] memory _shares
    ) internal onlyInitializing {
        require(_holders.length == _shares.length, "length mismatch");

        for (uint256 i = 0; i < _holders.length; i++) {
            require(
                kycManager.isKyc(_holders[i]),
                "can not pre mint for non kyc investor"
            );
            _setFirstDeposit(_holders[i]);
            _mint(_holders[i], _shares[i]);
        }
    }

    /**
     * @dev Initializes the vault with the underlying asset.
     * @param _underlying Address of the underlying asset.
     */
    function __vault_init(
        IERC20MetadataUpgradeable _underlying
    ) internal onlyInitializing {
        underlying = _underlying;
        tbillDecimalScaleFactor = 10 ** _underlying.decimals();
    }

    /**
     * @dev Common workflow for depositing/minting.
     * @param _sender Sender's address.
     * @param _receiver Receiver's address.
     * @param _assets Amount of assets to deposit.
     * @param _shares Number of shares to mint.
     * @param _assetsTo Address to transfer the assets to.
     */
    function _deposit(
        address _sender,
        address _receiver,
        uint256 _assets,
        uint256 _shares,
        address _assetsTo
    ) internal {
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(underlying),
            _sender,
            _assetsTo,
            _assets
        );
        _mint(_receiver, _shares);

        emit Deposit(_receiver, _assets, _shares);
    }

    /**
     * @dev Common workflow for withdrawing/redeeming.
     * @param _caller Caller's address.
     * @param _receiver Receiver's address.
     * @param _owner Owner's address.
     * @param _assets Amount of assets to withdraw.
     * @param _shares Number of shares to burn.
     */
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal {
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        _burn(_owner, _shares);
        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(underlying),
            _receiver,
            _assets
        );

        emit Withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /**
     * @dev Sets the first deposit flag for a given investor.
     * @param investor Investor's address.
     */
    function _setFirstDeposit(address investor) internal {
        firstDepositMap[investor] = true;
    }

    /**
     * @dev Computes the gap between two uint256 values.
     * @param a First value.
     * @param b Second value.
     * @return gap The difference between a and b.
     * @return isPositive True if a >= b, false otherwise.
     */
    function getGap(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256, bool) {
        if (a >= b) {
            return (a - b, true);
        } else {
            return (b - a, false);
        }
    }

    /**
     * @dev Decodes a given data bytes into its components.
     * @param _data Encoded data bytes.
     * @return sender Sender's address.
     * @return receiver Receiver's address.
     * @return shares Number of shares.
     * @return prevId Previous ID.
     */
    function _decodeData(
        bytes memory _data
    )
        internal
        pure
        returns (
            address sender,
            address receiver,
            uint256 shares,
            bytes32 prevId
        )
    {
        (sender, receiver, shares, prevId) = abi.decode(
            _data,
            (address, address, uint256, bytes32)
        );
    }

    /**
     * @dev Validates the KYC status of the given addresses.
     * @param _from Sender's address.
     * @param _to Receiver's address.
     */
    function _validateKyc(address _from, address _to) internal view {
        kycManager.onlyKyc(_from);
        kycManager.onlyNotBanned(_from);

        kycManager.onlyKyc(_to);
        kycManager.onlyNotBanned(_to);
    }
}
