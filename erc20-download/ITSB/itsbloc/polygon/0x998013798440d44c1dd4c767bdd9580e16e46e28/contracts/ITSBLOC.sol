// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ITSBLOC is ERC20 {
  string constant private _name = "ITSBLOC";
  string constant private _symbol = "ITSB";
  uint8 constant private _decimals = 18;
  uint256 constant private _initial_supply = 1_000_000_000;

  constructor() ERC20(_name, _symbol) {
    _mint(_msgSender(), _initial_supply * (10 ** uint256(_decimals)));
  }
}