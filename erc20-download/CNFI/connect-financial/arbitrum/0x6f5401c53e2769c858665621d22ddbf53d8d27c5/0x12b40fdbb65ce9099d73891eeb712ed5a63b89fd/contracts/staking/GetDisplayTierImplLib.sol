// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { StakingControllerLib } from "./StakingControllerLib.sol";

library GetDisplayTierImplLib {
  function _getDisplayTier(
    StakingControllerLib.Isolate storage isolate,
    uint256 tier,
    uint256 newBalance
  ) internal view returns (uint256) {
    for (; tier < isolate.tiersLength; tier++) {
      if (isolate.tiers[tier].minimum > newBalance) {
        tier--;
        break;
      }
    }
    if(tier >= isolate.tiersLength) tier--;
    return tier;
  }
}
