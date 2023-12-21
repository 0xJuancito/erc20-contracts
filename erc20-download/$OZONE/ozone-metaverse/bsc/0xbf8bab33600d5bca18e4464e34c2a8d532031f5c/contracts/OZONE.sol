// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// npm install @openzeppelin/contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract OZONE is ERC20, Ownable, ERC20Burnable {
  constructor() ERC20("OZONE", "OZONE") {
    _mint(msg.sender, 100 * (10 ** uint256(decimals())));
  }

  function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}