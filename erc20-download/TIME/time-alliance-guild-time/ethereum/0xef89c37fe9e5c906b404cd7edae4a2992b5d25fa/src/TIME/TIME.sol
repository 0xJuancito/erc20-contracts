// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TIME is ERC20 {
    constructor(uint256 supply) ERC20("Time Alliance Guild Time", "TIME") {
        _mint(msg.sender, supply);
    }
}
