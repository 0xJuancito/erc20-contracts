// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract VITCToken is ERC20 {
    constructor() ERC20("Vitamin Coin", "VITC") {
        _mint(msg.sender, 1e9 * 1e18);
    }
}