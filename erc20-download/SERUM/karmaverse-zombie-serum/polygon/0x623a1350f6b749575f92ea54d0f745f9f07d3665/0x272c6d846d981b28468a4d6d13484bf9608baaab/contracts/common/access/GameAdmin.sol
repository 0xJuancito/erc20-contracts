//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "./SuperAdmin.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

abstract contract GameAdmin is SuperAdmin {

    address internal gameAdmin;

    event GameAdminChanged(address oldAddress, address newAddress);

    error InvalidGameAdmin();

    function __GameAdmin_init_unchained() internal onlyInitializing {
        gameAdmin = msg.sender;
    }

    modifier onlyGameAdmin() {
        if (msg.sender != gameAdmin) revert InvalidGameAdmin();
        _;
    }

    function isGameAdmin(address addr) external view returns (bool) {
        return gameAdmin == addr;
    }

    function changeGameAdmin(address newAdmin) external onlySuperAdmin {
        emit GameAdminChanged(gameAdmin, newAdmin);
        gameAdmin = newAdmin;
    }

    function verify(bytes32 hash, bytes memory signature) public view returns (bool) {
        (address recovered, ECDSAUpgradeable.RecoverError error) = ECDSAUpgradeable.tryRecover(hash, signature);
        return error == ECDSAUpgradeable.RecoverError.NoError && recovered == gameAdmin;
    }
}