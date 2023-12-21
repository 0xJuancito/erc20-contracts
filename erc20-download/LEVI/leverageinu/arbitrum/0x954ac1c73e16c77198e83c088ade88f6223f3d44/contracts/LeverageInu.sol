// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LeverageInu is ERC20, Ownable {

  constructor() ERC20("LeverageInu", "LEVI") {
    _mint(msg.sender, 1_000_000 * 10 ** 18);
  }

  function burn(uint256 amount) external onlyOwner {
    _burn(msg.sender, amount);
  }
}

  
  
  