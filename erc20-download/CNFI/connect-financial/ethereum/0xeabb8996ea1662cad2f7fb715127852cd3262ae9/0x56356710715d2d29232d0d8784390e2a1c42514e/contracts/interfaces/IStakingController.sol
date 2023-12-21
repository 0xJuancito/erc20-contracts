// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IStakingController {
  function receiveCallback(address sender, address receiver) external;
}
