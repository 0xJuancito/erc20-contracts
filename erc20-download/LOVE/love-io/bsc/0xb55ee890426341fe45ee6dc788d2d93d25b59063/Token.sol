// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";

contract LoveToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Love.io", "LOVE") {
        _mint(msg.sender, initialSupply);
    }
}