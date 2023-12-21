// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "./ERC20AB.sol";

contract ERC20ABC is ERC20AB, ERC20Capped {
  constructor(string memory name, string memory symbol, uint256 cap) ERC20AB(name, symbol) ERC20Capped(cap) {}

  function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
    super._mint(account, amount);
  }
}
