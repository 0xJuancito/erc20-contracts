// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../contracts/Swych.sol";

contract $Swych is Swych {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    function $_IMPLEMENTATION_SLOT() external pure returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    function $_ADMIN_SLOT() external pure returns (bytes32) {
        return _ADMIN_SLOT;
    }

    function $_BEACON_SLOT() external pure returns (bytes32) {
        return _BEACON_SLOT;
    }

    function $_authorizeUpgrade(address newImplementation) external {
        super._authorizeUpgrade(newImplementation);
    }

    function $_getAvailableTradingBalanceAmountInternalInGons(address _address) external view returns (uint256 ret0) {
        (ret0) = super._getAvailableTradingBalanceAmountInternalInGons(_address);
    }

    function $_mint(address account,uint256 amount) external {
        super._mint(account,amount);
    }

    function $_swapBack() external {
        super._swapBack();
    }

    function $_swapAndLiquidify(uint256 totalFee,uint256 amountToSwap,uint256 amountToLiquify) external {
        super._swapAndLiquidify(totalFee,amountToSwap,amountToLiquify);
    }

    function $__UUPSUpgradeable_init() external {
        super.__UUPSUpgradeable_init();
    }

    function $__UUPSUpgradeable_init_unchained() external {
        super.__UUPSUpgradeable_init_unchained();
    }

    function $__ERC1967Upgrade_init() external {
        super.__ERC1967Upgrade_init();
    }

    function $__ERC1967Upgrade_init_unchained() external {
        super.__ERC1967Upgrade_init_unchained();
    }

    function $_getImplementation() external view returns (address ret0) {
        (ret0) = super._getImplementation();
    }

    function $_upgradeTo(address newImplementation) external {
        super._upgradeTo(newImplementation);
    }

    function $_upgradeToAndCall(address newImplementation,bytes calldata data,bool forceCall) external {
        super._upgradeToAndCall(newImplementation,data,forceCall);
    }

    function $_upgradeToAndCallUUPS(address newImplementation,bytes calldata data,bool forceCall) external {
        super._upgradeToAndCallUUPS(newImplementation,data,forceCall);
    }

    function $_getAdmin() external view returns (address ret0) {
        (ret0) = super._getAdmin();
    }

    function $_changeAdmin(address newAdmin) external {
        super._changeAdmin(newAdmin);
    }

    function $_getBeacon() external view returns (address ret0) {
        (ret0) = super._getBeacon();
    }

    function $_upgradeBeaconToAndCall(address newBeacon,bytes calldata data,bool forceCall) external {
        super._upgradeBeaconToAndCall(newBeacon,data,forceCall);
    }

    function $__Pausable_init() external {
        super.__Pausable_init();
    }

    function $__Pausable_init_unchained() external {
        super.__Pausable_init_unchained();
    }

    function $_requireNotPaused() external view {
        super._requireNotPaused();
    }

    function $_requirePaused() external view {
        super._requirePaused();
    }

    function $_pause() external {
        super._pause();
    }

    function $_unpause() external {
        super._unpause();
    }

    function $__Ownable_init() external {
        super.__Ownable_init();
    }

    function $__Ownable_init_unchained() external {
        super.__Ownable_init_unchained();
    }

    function $_checkOwner() external view {
        super._checkOwner();
    }

    function $_transferOwnership(address newOwner) external {
        super._transferOwnership(newOwner);
    }

    function $__Context_init() external {
        super.__Context_init();
    }

    function $__Context_init_unchained() external {
        super.__Context_init_unchained();
    }

    function $_msgSender() external view returns (address ret0) {
        (ret0) = super._msgSender();
    }

    function $_msgData() external view returns (bytes memory ret0) {
        (ret0) = super._msgData();
    }

    function $_disableInitializers() external {
        super._disableInitializers();
    }

    function $_getInitializedVersion() external view returns (uint8 ret0) {
        (ret0) = super._getInitializedVersion();
    }

    function $_isInitializing() external view returns (bool ret0) {
        (ret0) = super._isInitializing();
    }

    receive() external payable {}
}
