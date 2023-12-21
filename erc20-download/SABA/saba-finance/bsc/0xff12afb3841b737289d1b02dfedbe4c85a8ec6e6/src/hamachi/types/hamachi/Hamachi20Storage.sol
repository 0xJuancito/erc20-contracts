// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Hamachi20Storage {
  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowances;
  uint256 totalSupply;
  string name;
  string symbol;
  mapping(address => uint256) nonces;
}
