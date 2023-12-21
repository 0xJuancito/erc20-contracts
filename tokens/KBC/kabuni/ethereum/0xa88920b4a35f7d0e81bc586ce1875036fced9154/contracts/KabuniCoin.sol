// SPDX-License-Identifier: CC-BY-NC

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KabuniCoin is ERC20, Ownable {
  using SafeERC20 for IERC20;


  constructor() ERC20("Kabuni Coin", "KBC") {
    _mint(msg.sender, 1e9); // 1B initial supply
  }

  function mint(uint256 count) external onlyOwner {
    // Only the owner can mint new tokens & increase total supply
    _mint(owner(), count); // Could also be msg.sender, leaving as owner() as extra redunadancy to ensure only the owner gets KBC as the result of a mint
  }
}
