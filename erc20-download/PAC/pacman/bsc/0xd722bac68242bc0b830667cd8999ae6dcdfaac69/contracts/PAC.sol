// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PAC is ERC20, Ownable {
  constructor(uint256 initialSupply) ERC20("PAC Token", "PAC") {
    _mint(msg.sender, initialSupply);
  }

  function mint(uint256 amount) external onlyOwner {
    _mint(msg.sender, amount);
  }
}
