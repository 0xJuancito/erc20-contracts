// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {
  StakingControllerTemplate
} from '../staking/StakingControllerTemplate.sol';
import { StakingControllerLib } from '../staking/StakingControllerLib.sol';
import {
  MathUpgradeable as Math
} from '@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol';
import {
  SafeMathUpgradeable
} from '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';
import { ComputeCyclesHeldLib } from '../staking/ComputeCyclesHeldLib.sol';
import {
  UpdateRedeemableImplLib
} from '../staking/UpdateRedeemableImplLib.sol';
import { GetDisplayTierImplLib } from '../staking/GetDisplayTierImplLib.sol';
import {
  CalculateRewardsImplLib
} from '../staking/CalculateRewardsImplLib.sol';

contract Viewer is StakingControllerTemplate {
  using SafeMathUpgradeable for *;

  function render(address caller)
    public
    view
    returns (
      StakingControllerLib.Tier memory tier,
      StakingControllerLib.EncodeableCycle memory retCycle,
      StakingControllerLib.ReturnStats memory returnstats,
      StakingControllerLib.DailyUser memory dailyUser,
      StakingControllerLib.Tier[] memory _tiers,
      uint256 currentTier
    )
  {
    StakingControllerLib.Cycle storage _cycle;
    uint256 lastSeenCycle;
    StakingControllerLib.DetermineMultiplierLocals memory locals;
    if (caller != address(0x0)) {
      dailyUser = isolate.dailyUsers[caller];
      _tiers = new StakingControllerLib.Tier[](isolate.tiersLength);
      for (uint256 i = 1; i < isolate.tiersLength; i++) {
        _tiers[i] = isolate.tiers[i];
      }
      tier = isolate.tiers[dailyUser.commitment];
      _cycle = isolate.cycles[isolate.currentCycle];

      {
        returnstats.staked = isolate.sCnfi.balanceOf(caller);
        returnstats.lockCommitment = dailyUser.commitment;
      }
      lastSeenCycle = isolate.currentCycle;

      returnstats.cycleChange = dailyUser.cyclesHeld;
      StakingControllerLib.UserWeightChanges storage _weightChange =
        isolate.weightChanges[caller];
      returnstats.totalCyclesSeen = _weightChange.totalCyclesSeen;

      locals.tierIndex = Math.max(dailyUser.commitment, dailyUser.currentTier);
      locals.tier = isolate.tiers[locals.tierIndex];
      {
        locals.scnfiBalance = isolate.sCnfi.balanceOf(caller);
      }
      {
        returnstats.currentCnfiBalance = isolate.cnfi.balanceOf(caller);
        currentTier = GetDisplayTierImplLib._getDisplayTier(
          isolate,
          Math.max(dailyUser.currentTier, dailyUser.commitment),
          returnstats.staked
        );
        returnstats.redeemable = dailyUser.redeemable;
        (, returnstats.bonuses) = CalculateRewardsImplLib._computeRewards(
          isolate,
          caller
        );
      }
    }
    _cycle = isolate.cycles[isolate.currentCycle];
    retCycle = StakingControllerLib.EncodeableCycle(
      _cycle.totalWeight,
      _cycle.totalRawWeight,
      _cycle.pCnfiToken,
      _cycle.reserved,
      _cycle.day,
      _cycle.canUnstake,
      lastSeenCycle,
      isolate.currentCycle
    );

    {
      returnstats.totalStakedInProtocol = isolate.sCnfi.totalSupply();
    }
    returnstats.cnfiReleasedPerDay = isolate.inflateBy;
    returnstats.basePenalty = isolate.baseUnstakePenalty;
    returnstats.commitmentViolationPenalty = isolate.commitmentViolationPenalty;
    returnstats.totalWeight = isolate.totalWeight;
    return (locals.tier, retCycle, returnstats, dailyUser, _tiers, currentTier);
  }
}
