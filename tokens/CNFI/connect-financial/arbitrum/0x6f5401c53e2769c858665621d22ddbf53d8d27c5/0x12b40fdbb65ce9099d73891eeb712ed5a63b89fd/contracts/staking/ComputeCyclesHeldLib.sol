// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {
  SafeMathUpgradeable
} from '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';

library ComputeCyclesHeldLib {
  using SafeMathUpgradeable for *;

  function _computeCyclesHeld(
    uint256 cycleEnd,
    uint256 interval,
    uint256 _cyclesHeld,
    uint256 currentTimestamp
  ) internal pure returns (uint256 newCycleEnd, uint256 newCyclesHeld) {
    if (cycleEnd == 0) cycleEnd = currentTimestamp.add(interval);
    if (cycleEnd > currentTimestamp) return (cycleEnd, _cyclesHeld);
    uint256 additionalCycles = currentTimestamp.sub(cycleEnd).div(interval);
    newCyclesHeld = _cyclesHeld.add(1).add(additionalCycles);
    newCycleEnd = cycleEnd.add(interval.mul(additionalCycles.add(1)));
  }
}
