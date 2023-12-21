// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyraToken is ERC20 {
    constructor() ERC20("MYRA", "MYR") {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }
}