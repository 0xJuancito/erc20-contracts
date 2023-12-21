// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

import "DelegableToLT.sol";

contract ProjectToken is DelegableToLT {
  // ERC20 and Ownable standard functions are already included in DelegableToLT (but not SafeMath)
  constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {
  }
}
