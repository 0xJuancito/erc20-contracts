// SPDX-License-Identifier: MIT
// Created by Flux Team

pragma solidity 0.6.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Flux is ERC20 {
    constructor() public ERC20("Flux Protocol", "FLUX") {
        // total suplly = 2100 万
        _mint(msg.sender, 21000000 * 1e18);
    }
}

contract hFlux is ERC20 {
    address constant PLOY_LOCKED_PROXY = 0x020c15e7d08A8Ec7D35bCf3AC3CCbF0BBf2704e6;

    constructor() public ERC20("Flux Protocol", "hFLUX") {
        // total suplly = 2100 万
        _mint(PLOY_LOCKED_PROXY, 21000000 * 1e18);
    }
}

contract bFlux is ERC20 {
    address constant PLOY_LOCKED_PROXY = 0x2f7ac9436ba4B548f9582af91CA1Ef02cd2F1f03;

    constructor() public ERC20("Flux Protocol", "bFLUX") {
        // total suplly = 2100 万
        _mint(PLOY_LOCKED_PROXY, 21000000 * 1e18);
    }
}

contract FLUXK is ERC20 {
    constructor() public ERC20("Flux Protocol", "FLUXK") {
        // total suplly = 2100 万
        _mint(msg.sender, 21000000 * 1e18);
    }
}
