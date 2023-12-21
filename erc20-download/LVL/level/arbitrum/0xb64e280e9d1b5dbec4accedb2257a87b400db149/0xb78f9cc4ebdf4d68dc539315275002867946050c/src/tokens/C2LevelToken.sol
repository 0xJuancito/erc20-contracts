// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {BaseBridgedERC20} from "./BaseBridgedERC20.sol";

/// @notice Briged LVL
contract C2LevelTokenReinit is BaseBridgedERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __BaseBridgedERC20_init("Level Token", "LVL");
    }

    function reinit(address owner_) external reinitializer(2) {
        _transferOwnership(owner_);
    }
}

contract C2LevelToken is BaseBridgedERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __BaseBridgedERC20_init("Level Token", "LVL");
    }
}
