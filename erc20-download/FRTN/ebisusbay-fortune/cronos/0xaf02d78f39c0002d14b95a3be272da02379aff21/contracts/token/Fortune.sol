// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Fortune is ERC20Burnable {
    constructor() ERC20("Fortune", "FRTN") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}