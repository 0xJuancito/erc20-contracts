// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract NvirToken is ERC20, ERC20Burnable, Ownable {
  constructor(
    string memory name_,
    string memory symbol_,
    uint256 initialSupply
  ) ERC20(name_, symbol_) Ownable(msg.sender) {
    _mint(msg.sender, initialSupply);
  }
}
