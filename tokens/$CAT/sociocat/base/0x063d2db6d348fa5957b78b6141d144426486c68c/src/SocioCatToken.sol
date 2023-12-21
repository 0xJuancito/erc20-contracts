// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from
  "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract SocioCatToken is ERC20, ERC20Permit {
  constructor(address _treasury, string memory _name, string memory _symbol)
    ERC20(_name, _symbol)
    ERC20Permit(_name)
  {
    _mint(_treasury, 1_000_000_000 ether);
  }
}
