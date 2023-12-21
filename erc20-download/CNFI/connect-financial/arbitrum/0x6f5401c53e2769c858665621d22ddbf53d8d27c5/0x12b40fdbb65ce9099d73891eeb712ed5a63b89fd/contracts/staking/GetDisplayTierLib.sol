// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { StakingControllerLib } from "./StakingControllerLib.sol";
import { GetDisplayTierImplLib } from "./GetDisplayTierImplLib.sol";

library GetDisplayTierLib {
  function getDisplayTier(
    StakingControllerLib.Isolate storage isolate,
    uint256 tier,
    uint256 newBalance
  ) external view returns (uint256) {
    return GetDisplayTierImplLib._getDisplayTier(isolate, tier, newBalance);
  }
}
