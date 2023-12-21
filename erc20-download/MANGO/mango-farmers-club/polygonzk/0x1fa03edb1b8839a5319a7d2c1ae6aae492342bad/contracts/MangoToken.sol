// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MangoToken is ERC20 {
    constructor() ERC20("Mango Farmers Club", "MANGO") {
        _mint(0x7D97304bcFC75E10def10db3A71d7FF76ce11bD0, 10000000000 * 10**18);
    }
}
