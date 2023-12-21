// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "./SecurityPresetUpgradeable.sol";

abstract contract MinterPresetUpgradeable is SecurityPresetUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function __MinterPresetUpgradeable_init() public initializer {
        SecurityPresetUpgradeable.__SecurityPresetUpgradeable_init();
        __MinterPresetUpgradeable_init_unchained();
    }

    function __MinterPresetUpgradeable_init_unchained() internal initializer {
        AccessControlUpgradeable._setupRole(MINTER_ROLE, _msgSender());
    }

    uint256[50] private __gap;
}
