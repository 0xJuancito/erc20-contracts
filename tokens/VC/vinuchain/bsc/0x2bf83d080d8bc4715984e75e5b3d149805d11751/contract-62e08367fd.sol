// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Burnable.sol";

/// @custom:security-contact hello@vitainu.org
contract VinuChain is ERC20, ERC20Burnable {
    constructor() ERC20("VinuChain", "VC") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}
