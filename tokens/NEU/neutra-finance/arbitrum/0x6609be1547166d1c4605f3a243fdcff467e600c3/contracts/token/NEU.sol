// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./base/MintableERC20.sol";

contract NEU is MintableERC20 {
    constructor() MintableERC20("NEU", "NEU") {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}