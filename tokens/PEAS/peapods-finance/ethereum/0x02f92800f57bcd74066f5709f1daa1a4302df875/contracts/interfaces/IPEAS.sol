// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IPEAS is IERC20 {
  event Burn(address indexed user, uint256 amount);

  function burn(uint256 amount) external;
}
