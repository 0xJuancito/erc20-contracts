// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Socap is ERC20, Ownable {
    constructor () ERC20("Socap", "Socap") {
        _mint(msg.sender, 15e7 * (10 ** uint256(decimals())));
    }
}