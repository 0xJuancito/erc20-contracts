// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Permit.sol";

contract PayItNow is ERC20, ERC20Permit {
    constructor() ERC20("Pay it Now", "PIN") ERC20Permit("Pay it Now") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }
}
