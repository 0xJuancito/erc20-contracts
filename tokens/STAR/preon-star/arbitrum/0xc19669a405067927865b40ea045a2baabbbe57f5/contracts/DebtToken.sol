// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Dependencies/ERC20Permit.sol";
import "./Interfaces/IDebtToken.sol";
import "./Interfaces/IPriceProvider.sol";

contract DebtToken is OFTV2, IDebtToken, ERC20Permit, Pausable {
    /// @notice bridge fee reciever
    address public treasury;

    /// @notice Fee ratio for bridging, in bips
    uint256 public feeRatio;

    /// @notice Divisor for fee ratio, 100%
    uint256 public constant FEE_DIVISOR = 10000;
    uint256 maxSTARMintable;

    string public constant NAME = "STAR";
    address public immutable vesselManagerAddress;
    IStabilityPool public immutable stabilityPool;
    address public immutable borrowerOperationsAddress;

    mapping(address => bool) public emergencyStopMintingCollateral;

    // stores SC addresses that are allowed to mint/burn the token (AMO strategies, L2 suppliers)
    mapping(address => bool) public whitelistedContracts;

    address public immutable timelockAddress;

    /// @notice PriceProvider, for PREON price in native fee calc
    IPriceProvider public priceProvider;

    bool public isInitialized;

    error DebtToken__TimelockOnly();
    error DebtToken__OwnerOnly();

    /// @notice Emitted when fee ratio is updated
    event FeeUpdated(uint256 fee);

    /// @notice Emitted when PriceProvider is updated
    event PriceProviderUpdated(IPriceProvider indexed priceProvider);

    /// @notice Emitted when Treasury is updated
    event TreasuryUpdated(address indexed treasury);

    modifier onlyTimelock() {
        if (isInitialized) {
            if (msg.sender != timelockAddress) {
                revert DebtToken__TimelockOnly();
            }
        } else {
            if (msg.sender != owner()) {
                revert DebtToken__OwnerOnly();
            }
        }
        _;
    }

    constructor(
        address _vesselManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _timelockAddress,
        address _endpoint,
        address _treasury
    ) OFTV2("STAR", "STAR", 8, _endpoint) {
        require(_endpoint != address(0), "invalid LZ Endpoint");
        require(_treasury != address(0), "invalid treasury");
        vesselManagerAddress = _vesselManagerAddress;
        timelockAddress = _timelockAddress;
        stabilityPool = IStabilityPool(_stabilityPoolAddress);
        borrowerOperationsAddress = _borrowerOperationsAddress;

        treasury = _treasury;
    }

    function setInitialized() public onlyOwner {
        isInitialized = true;
    }

    /**
     * @notice Returns LZ fee + Bridge fee
     * @dev overrides default OFT estimate fee function to add native fee
     * @param _dstChainId dest LZ chain id
     * @param _toAddress to addr on dst chain
     * @param _amount amount to bridge
     * @param _useZro use ZRO token, someday ;)
     * @param _adapterParams LZ adapter params
     */
    function estimateSendFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) public view override returns (uint256 nativeFee, uint256 zroFee) {
        (nativeFee, zroFee) = super.estimateSendFee(
            _dstChainId,
            _toAddress,
            _amount,
            _useZro,
            _adapterParams
        );
        nativeFee = nativeFee + (getBridgeFee(_amount));
    }

    /**
     * @notice Returns LZ fee + Bridge fee
     * @dev overrides default OFT _send function to add native fee
     * @param _from from addr
     * @param _dstChainId dest LZ chain id
     * @param _toAddress to addr on dst chain
     * @param _amount amount to bridge
     * @param _refundAddress refund addr
     * @param _zroPaymentAddress use ZRO token, someday ;)
     * @param _adapterParams LZ adapter params
     */
    function _send(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal override returns (uint256 amount) {
        uint256 fee = getBridgeFee(_amount);
        require(msg.value >= fee, "ETH sent is not enough for fee");
        payable(treasury).transfer(fee);

        _checkAdapterParams(_dstChainId, PT_SEND, _adapterParams, NO_EXTRA_GAS);

        (amount, ) = _removeDust(_amount);
        amount = _debitFrom(_from, _dstChainId, _toAddress, amount);
        // amount returned should not have dust
        require(amount > 0, "OFTCore: amount too small");

        bytes memory lzPayload = _encodeSendPayload(_toAddress, _ld2sd(amount));
        _lzSend(
            _dstChainId,
            lzPayload,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams,
            msg.value - (fee)
        );

        emit SendToChain(_dstChainId, _from, _toAddress, amount);
    }

    /**
     * @notice overrides default OFT _debitFrom function to make pauseable
     * @param _from from addr
     * @param _dstChainId dest LZ chain id
     * @param _toAddress to addr on dst chain
     * @param _amount amount to bridge
     */
    function _debitFrom(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount
    ) internal override whenNotPaused returns (uint256) {
        return super._debitFrom(_from, _dstChainId, _toAddress, _amount);
    }

    /**
     * @notice Bridge fee amount
     * @param _PREONAmount amount for bridge
     */
    function getBridgeFee(uint256 _PREONAmount) public view returns (uint256) {
        if (address(priceProvider) == address(0)) {
            return 0;
        }
        uint256 priceInEth = priceProvider.getTokenPrice();
        uint256 priceDecimals = priceProvider.decimals();
        uint256 PREONInEth = (((_PREONAmount * priceInEth) /
            (10 ** priceDecimals)) * (10 ** 18)) / (10 ** decimals());

        return (PREONInEth * (feeRatio)) / (FEE_DIVISOR);
    }

    /**
     * @notice Set fee info
     * @param _fee ratio
     */
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1e4, "Invalid ratio");
        feeRatio = _fee;
        emit FeeUpdated(_fee);
    }

    /**
     * @notice Set price provider
     * @param _priceProvider address
     */
    function setPriceProvider(
        IPriceProvider _priceProvider
    ) external onlyOwner {
        require(address(_priceProvider) != address(0), "invalid PriceProvider");
        priceProvider = _priceProvider;
        emit PriceProviderUpdated(_priceProvider);
    }

    /**
     * @notice Set Treasury
     * @param _treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "invalid Treasury address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // --- Functions for intra-Preon calls ---

    //
    function emergencyStopMinting(
        address _asset,
        bool status
    ) external override onlyOwner {
        emergencyStopMintingCollateral[_asset] = status;
        emit EmergencyStopMintingCollateral(_asset, status);
    }

    function mintFromWhitelistedContract(uint256 _amount) external override {
        _requireCallerIsWhitelistedContract();
        _mint(msg.sender, _amount);
    }

    function burnFromWhitelistedContract(uint256 _amount) external override {
        _requireCallerIsWhitelistedContract();
        _burn(msg.sender, _amount);
    }

    function mint(
        address _asset,
        address _account,
        uint256 _amount
    ) external override {
        _requireCallerIsBorrowerOperations();
        require(
            !emergencyStopMintingCollateral[_asset],
            "Mint is blocked on this collateral"
        );

        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override {
        _requireCallerIsBOorVesselMorSP();
        _burn(_account, _amount);
    }

    function addWhitelist(address _address) external override onlyTimelock {
        whitelistedContracts[_address] = true;

        emit WhitelistChanged(_address, true);
    }

    function removeWhitelist(address _address) external override onlyOwner {
        whitelistedContracts[_address] = false;

        emit WhitelistChanged(_address, false);
    }

    function sendToPool(
        address _sender,
        address _poolAddress,
        uint256 _amount
    ) external override {
        _requireCallerIsStabilityPool();
        _transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(
        address _poolAddress,
        address _receiver,
        uint256 _amount
    ) external override {
        _requireCallerIsVesselMorSP();
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function transfer(
        address recipient,
        uint256 amount
    ) public override(IERC20, ERC20) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override(IERC20, ERC20) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "DebtToken: Cannot transfer tokens directly to the token contract or the zero address"
        );
        require(
            address(stabilityPool) != _recipient &&
                _recipient != vesselManagerAddress &&
                _recipient != borrowerOperationsAddress,
            "DebtToken: Cannot transfer tokens directly to the StabilityPool, VesselManager or BorrowerOps"
        );
    }

    function _requireCallerIsWhitelistedContract() internal view {
        require(
            whitelistedContracts[msg.sender],
            "DebtToken: Caller is not a whitelisted SC"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(
            msg.sender == borrowerOperationsAddress,
            "DebtToken: Caller is not BorrowerOperations"
        );
    }

    function _requireCallerIsBOorVesselMorSP() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
                msg.sender == vesselManagerAddress ||
                address(stabilityPool) == msg.sender,
            "DebtToken: Caller is neither BorrowerOperations nor VesselManager nor StabilityPool"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        require(
            address(stabilityPool) == msg.sender,
            "DebtToken: Caller is not the StabilityPool"
        );
    }

    function _requireCallerIsVesselMorSP() internal view {
        require(
            msg.sender == vesselManagerAddress ||
                address(stabilityPool) == msg.sender,
            "DebtToken: Caller is neither VesselManager nor StabilityPool"
        );
    }
}
