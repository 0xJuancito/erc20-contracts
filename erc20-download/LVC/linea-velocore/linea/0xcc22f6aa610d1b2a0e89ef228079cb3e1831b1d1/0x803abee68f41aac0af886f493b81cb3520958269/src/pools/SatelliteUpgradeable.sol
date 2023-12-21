// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Pool.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

abstract contract SatelliteUpgradeable is Satellite, ERC1967Upgrade {
    function upgradeTo(address newImplementation) external authenticate {
        ERC1967Upgrade._upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external authenticate {
        ERC1967Upgrade._upgradeToAndCall(newImplementation, data, true);
    }
}
