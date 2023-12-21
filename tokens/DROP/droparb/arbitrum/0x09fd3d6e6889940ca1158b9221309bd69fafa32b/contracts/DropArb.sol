// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DropArb is ERC20 {
    constructor() ERC20("DropArb", "DROP") {
        _mint(msg.sender, 690000000000000 * 10 ** decimals());
    }
}