// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract XCRE is ERC20, ERC20Burnable, ERC20Permit {
    constructor()
        ERC20("Cresio", "XCRE")
        ERC20Permit("Cresio")
    {
        _mint(msg.sender, 40000000 * 10 ** decimals());
    }
}