// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { StakingControllerTemplate } from "../staking/StakingControllerTemplate.sol";

contract MockView is StakingControllerTemplate {
  function render() public view returns (address) {
    return isolate.pCnfiImplementation;
  }
}
