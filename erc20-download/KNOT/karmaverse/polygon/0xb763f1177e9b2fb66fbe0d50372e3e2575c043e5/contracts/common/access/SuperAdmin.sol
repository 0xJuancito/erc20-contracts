//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

abstract contract SuperAdmin is PausableUpgradeable {
    address private superAdmin;

    event SuperAdminChanged(address oldAddress, address newAddress);

    error InvalidSuperAdmin();

    function __SuperAdmin_init_unchained() internal onlyInitializing {
        superAdmin = msg.sender;
    }

    modifier onlySuperAdmin() {
        if (msg.sender != superAdmin) revert InvalidSuperAdmin();
        _;
    }

    function isSuperAdmin(address addr) external view returns (bool) {
        return superAdmin == addr;
    }

    function changeSuperAdmin(address newAdmin) external onlySuperAdmin {
        emit SuperAdminChanged(superAdmin, newAdmin);
        superAdmin = newAdmin;
    }

    function pause() external onlySuperAdmin {
        _pause();
    }

    function unpause() external onlySuperAdmin {
        _unpause();
    }
}