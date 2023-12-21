// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract Plxyer is ERC20, ERC20Permit {
    constructor(address to) ERC20("Plxyer", "PLXY") ERC20Permit("Plxyer") {
        _mint(to,10000000000000000000000000000);
    }
}