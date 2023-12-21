// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract WithSupervisedTransfers is AccessControl {
    bytes32 public constant ALLOWED_TRANSFER_ROLE = keccak256("ALLOWED_TRANSFER_ROLE");
    bytes32 public constant ALLOWED_TRANSFER_FROM_ROLE = keccak256("ALLOWED_TRANSFER_FROM_ROLE");

    bytes32 public constant SUPERVISED_TRANSFER_ADMIN_ROLE = keccak256("SUPERVISED_TRANSFER_ADMIN_ROLE");
    bytes32 public constant SUPERVISED_TRANSFER_FROM_ADMIN_ROLE = keccak256("SUPERVISED_TRANSFER_FROM_ADMIN_ROLE");

    bytes32 public constant SUPERVISED_TRANSFER_MANAGER_ROLE = keccak256("SUPERVISED_TRANSFER_MANAGER_ROLE");
    bytes32 public constant SUPERVISED_TRANSFER_FROM_MANAGER_ROLE = keccak256("SUPERVISED_TRANSFER_FROM_MANAGER_ROLE");

    bool public isTransferSupervised = true;
    bool public isTransferFromSupervised = true;

    event SupervisedTransferRenounced();

    event SupervisedTransferFromRenounced();

    modifier onlyAllowedTransfer() {
        require(isTransferAllowed(_msgSender()), "WithSupervisedTransfers: account not allowed to transfer");
        _;
    }

    modifier onlyAllowedTransferFrom() {
        require(isTransferFromAllowed(_msgSender()), "WithSupervisedTransfers: account not allowed to transferFrom");
        _;
    }

    constructor() {
        address sender = _msgSender();

        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        _grantRole(ALLOWED_TRANSFER_ROLE, sender);
        _grantRole(ALLOWED_TRANSFER_FROM_ROLE, sender);

        _grantRole(SUPERVISED_TRANSFER_ADMIN_ROLE, sender);
        _grantRole(SUPERVISED_TRANSFER_FROM_ADMIN_ROLE, sender);

        _grantRole(SUPERVISED_TRANSFER_MANAGER_ROLE, sender);
        _grantRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE, sender);
    }

    function isTransferAllowed(address account) public view returns (bool) {
        return !isTransferSupervised || hasRole(ALLOWED_TRANSFER_ROLE, account);
    }

    function isTransferFromAllowed(address account) public view returns (bool) {
        return !isTransferFromSupervised || hasRole(ALLOWED_TRANSFER_FROM_ROLE, account);
    }

    /* TRANSFER_ROLE managment
     ****************************************************************/

    function allowTransferBy(address account) public onlyRole(SUPERVISED_TRANSFER_MANAGER_ROLE) {
        _grantRole(ALLOWED_TRANSFER_ROLE, account);
    }

    function disallowTransferBy(address account) public onlyRole(SUPERVISED_TRANSFER_MANAGER_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_ROLE, account);
    }

    function renounceSupervisedTransfer() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isTransferSupervised = false;

        emit SupervisedTransferRenounced();
    }

    function addSupervisedTransferAdmin(address admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ALLOWED_TRANSFER_ROLE, admin);
        _grantRole(SUPERVISED_TRANSFER_ADMIN_ROLE, admin);
        _grantRole(SUPERVISED_TRANSFER_MANAGER_ROLE, admin);
    }

    function removeSupervisedTransferAdmin(address admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_ROLE, admin);
        _revokeRole(SUPERVISED_TRANSFER_ADMIN_ROLE, admin);
        _revokeRole(SUPERVISED_TRANSFER_MANAGER_ROLE, admin);
    }

    function addSupervisedTransferManager(address manager) public onlyRole(SUPERVISED_TRANSFER_ADMIN_ROLE) {
        _grantRole(ALLOWED_TRANSFER_ROLE, manager);
        _grantRole(SUPERVISED_TRANSFER_MANAGER_ROLE, manager);
    }

    function removeSupervisedTransferManager(address manager) public onlyRole(SUPERVISED_TRANSFER_ADMIN_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_ROLE, manager);
        _revokeRole(SUPERVISED_TRANSFER_MANAGER_ROLE, manager);
    }

    /* TRANSFER_FROM_ROLE managment
     ****************************************************************/

    function allowTransferFromBy(address account) public onlyRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE) {
        _grantRole(ALLOWED_TRANSFER_FROM_ROLE, account);
    }

    function disallowTransferFromBy(address account) public onlyRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_FROM_ROLE, account);
    }

    function renounceSupervisedTransferFrom() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isTransferFromSupervised = false;

        emit SupervisedTransferFromRenounced();
    }

    function addSupervisedTransferFromAdmin(address admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ALLOWED_TRANSFER_FROM_ROLE, admin);
        _grantRole(SUPERVISED_TRANSFER_FROM_ADMIN_ROLE, admin);
        _grantRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE, admin);
    }

    function removeSupervisedTransferFromAdmin(address admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_FROM_ROLE, admin);
        _revokeRole(SUPERVISED_TRANSFER_FROM_ADMIN_ROLE, admin);
        _revokeRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE, admin);
    }

    function addSupervisedTransferFromManager(address manager) public onlyRole(SUPERVISED_TRANSFER_FROM_ADMIN_ROLE) {
        _grantRole(ALLOWED_TRANSFER_FROM_ROLE, manager);
        _grantRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE, manager);
    }

    function removeSupervisedTransferFromManager(address manager) public onlyRole(SUPERVISED_TRANSFER_FROM_ADMIN_ROLE) {
        _revokeRole(ALLOWED_TRANSFER_FROM_ROLE, manager);
        _revokeRole(SUPERVISED_TRANSFER_FROM_MANAGER_ROLE, manager);
    }
}
