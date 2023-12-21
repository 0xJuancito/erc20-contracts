// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRSRV is IERC20 {
  function uniswapV2Router() external view returns (address);
  function uniswapV2Pair() external view returns (address);
  function mint(uint amount) external;
}