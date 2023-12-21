// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MonolendToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
  constructor(uint256 initialSupply) ERC20("Monolend", "MLD") ERC20Permit("Monolend") {
    _mint(msg.sender, initialSupply);
  }
}