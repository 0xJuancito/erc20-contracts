// contracts/DaddyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ESPENTOUSD is ERC20, Ownable {
  constructor(uint256 initialSupply, address to) ERC20("ESPENTO-USD", "eUSD") {
    _mint(to, initialSupply);
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
    address owner = _msgSender();
    _approve(owner, spender, allowance(owner, spender) + addedValue);
    return true;
  }

  function burn(uint256 _amount) external {
    _burn(msg.sender, _amount);
  }

  function mint(uint256 amount, address account) external onlyOwner returns (bool) {
    _mint(account, amount);
    return true;
  }
}
