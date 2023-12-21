// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';

contract Permissioned is AccessControlEnumerable {
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256('ACCESS_MANAGER_ROLE');
    bytes32 public constant PERMITTED_ROLE = keccak256('PERMITTED_ROLE');
    bool public isPermissioned = true;

    event AccessModeUpdated(bool isPermissioned);

    modifier onlyPermitted() {
        if (isPermissioned) {
            require(hasRole(PERMITTED_ROLE, msg.sender), 'Permissioned mode: Only permitted can transact');
        }
        _;
    }

    function addAccessManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ACCESS_MANAGER_ROLE, manager);
    }

    function removeAccessManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ACCESS_MANAGER_ROLE, manager);
    }

    function addPermitted(address permitted) external onlyRole(ACCESS_MANAGER_ROLE) {
        _grantRole(PERMITTED_ROLE, permitted);
    }

    function removePermitted(address permitted) external onlyRole(ACCESS_MANAGER_ROLE) {
        _revokeRole(PERMITTED_ROLE, permitted);
    }

    function setIsPermissioned(bool isPermissioned_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isPermissioned != isPermissioned_) {
            isPermissioned = isPermissioned_;
            emit AccessModeUpdated(isPermissioned_);
        }
    }
}
