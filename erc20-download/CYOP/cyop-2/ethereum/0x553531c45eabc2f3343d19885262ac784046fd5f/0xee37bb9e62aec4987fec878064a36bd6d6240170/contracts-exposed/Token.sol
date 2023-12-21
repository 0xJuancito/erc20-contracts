// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../contracts/Token.sol";

contract $CyOp is CyOp {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() payable {
    }

    function $_IMPLEMENTATION_SLOT() external pure returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    function $_ADMIN_SLOT() external pure returns (bytes32) {
        return _ADMIN_SLOT;
    }

    function $_BEACON_SLOT() external pure returns (bytes32) {
        return _BEACON_SLOT;
    }

    function $_balances(address arg0) external view returns (uint256) {
        return _balances[arg0];
    }

    function $_totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function $_transfer(address from,address to,uint256 amount) external {
        super._transfer(from,to,amount);
    }

    function $_distributeTaxes(uint256 amount) external {
        super._distributeTaxes(amount);
    }

    function $_sendViaCall(address payable _to,uint256 amountETH) external {
        super._sendViaCall(_to,amountETH);
    }

    function $_authorizeUpgrade(address newImplementation) external {
        super._authorizeUpgrade(newImplementation);
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

    function $__ERC20_init(string calldata name_,string calldata symbol_) external {
        super.__ERC20_init(name_,symbol_);
    }

    function $__ERC20_init_unchained(string calldata name_,string calldata symbol_) external {
        super.__ERC20_init_unchained(name_,symbol_);
    }

    function $_mint(address account,uint256 amount) external {
        super._mint(account,amount);
    }

    function $_burn(address account,uint256 amount) external {
        super._burn(account,amount);
    }

    function $_approve(address owner,address spender,uint256 amount) external {
        super._approve(owner,spender,amount);
    }

    function $_spendAllowance(address owner,address spender,uint256 amount) external {
        super._spendAllowance(owner,spender,amount);
    }

    function $_beforeTokenTransfer(address from,address to,uint256 amount) external {
        super._beforeTokenTransfer(from,to,amount);
    }

    function $_afterTokenTransfer(address from,address to,uint256 amount) external {
        super._afterTokenTransfer(from,to,amount);
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
}
