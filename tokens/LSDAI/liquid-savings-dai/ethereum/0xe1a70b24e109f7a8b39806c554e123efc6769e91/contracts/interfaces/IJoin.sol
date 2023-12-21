// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IJoin {
  function join(address, uint256) external;

  function exit(address, uint256) external;
}
