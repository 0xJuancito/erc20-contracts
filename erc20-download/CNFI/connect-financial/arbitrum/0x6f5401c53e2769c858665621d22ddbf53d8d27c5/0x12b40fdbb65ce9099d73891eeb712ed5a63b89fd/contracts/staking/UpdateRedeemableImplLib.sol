// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {
  SafeMathUpgradeable
} from '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';
import { StakingControllerLib } from './StakingControllerLib.sol';
import {
  MathUpgradeable as Math
} from '@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol';
import { UpdateToLastImplLib } from './UpdateToLastImplLib.sol';
import { sCNFI } from '../token/sCNFI.sol';
import { ComputeCyclesHeldLib } from './ComputeCyclesHeldLib.sol';
import { BancorFormulaLib } from '../math/BancorFormulaLib.sol';


library UpdateRedeemableImplLib {
  using SafeMathUpgradeable for *;
  using BancorFormulaLib for *;

  function _updateCumulativeRewards(
    StakingControllerLib.Isolate storage isolate,
    address _user
  ) internal {
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[_user];
    if (user.multiplier == 0) user.multiplier = uint256(1 ether);
    if (isolate.currentDay > user.lastDaySeen) {
      user.cumulativeRewardWeight = user.cumulativeRewardWeight.add(
        isolate.currentDay.sub(user.lastDaySeen).mul(user.weight)
      );
    } else user.cumulativeRewardWeight = 0;
  }

  function _updateRedeemable(
    StakingControllerLib.Isolate storage isolate,
    StakingControllerLib.DailyUser storage user,
    uint256 multiplier
  ) internal view returns (uint256 redeemable, uint256 bonuses) {
    StakingControllerLib.DetermineInflateLocals memory locals;
    locals.lastDayInEpoch = isolate.currentDay - 1;
    locals.lastDayChanged = user.lastDaySeen;
    if (locals.lastDayChanged < isolate.currentDay) {
      locals.dayDifference = isolate.currentDay.sub(locals.lastDayChanged);
      /*
            locals.totalWeight = isolate.cumulativeTotalWeight.sub(
                user.cumulativeTotalWeight
            );
            if (locals.totalWeight == 0) return (0, 0);
*/

      uint256 denominator =
        Math.max(
          Math.min(
            isolate.cumulativeTotalWeight.sub(user.cumulativeTotalWeight),
            Math.max(Math.max(isolate.totalWeight, isolate.lastTotalWeight), user.lastTotalWeight).mul(locals.dayDifference)
          ),
          uint256(1 ether)
        );
    
      redeemable = locals
        .dayDifference
        .mul(isolate.inflateBy)
        .mul(user.cumulativeRewardWeight)
        .div(denominator);

      if (multiplier > uint256(1 ether))
        bonuses = redeemable.mul(multiplier.sub(uint256(1 ether))).div(
          multiplier
        );
      else bonuses = 0;
    }
  }

  function _determineMultiplier(
    StakingControllerLib.Isolate storage isolate,
    bool penaltyChange,
    address user,
    uint256 currentBalance
  ) internal returns (uint256 multiplier, uint256 amountToBurn) {
    StakingControllerLib.DetermineMultiplierLocals memory locals;
    StakingControllerLib.User storage currentUser =
      isolate.cycles[isolate.currentCycle].users[user];
    locals.minimum = uint256(~0);
    locals.tierIndex = isolate.lockCommitments[user];
    locals.tier = isolate.tiers[locals.tierIndex];
    locals.cyclesHeld = 0;
    locals.multiplier = locals.tierIndex == 0
      ? 1 ether
      : locals.tier.multiplier;
    for (uint256 i = isolate.currentCycle; i > 0; i--) {
      StakingControllerLib.Cycle storage cycle = isolate.cycles[i];
      StakingControllerLib.User storage _user = cycle.users[user];
      locals.minimum = Math.min(locals.minimum, _user.minimumWeight);
      currentUser.cyclesHeld = locals.cyclesHeld;
      currentUser.currentTier = locals.tierIndex;
      if (locals.minimum < locals.tier.minimum) {
        if (
          isolate.lockCommitments[user] == locals.tierIndex && penaltyChange
        ) {
          uint256 bonus = isolate.bonusesAccrued[user];
          amountToBurn = Math.min(bonus, currentBalance);

          if (amountToBurn > 0) {
            isolate.bonusesAccrued[user] = 0;
            isolate.lockCommitments[user] = 0;
            currentUser.currentTier = 0;
            currentUser.cyclesHeld = 0;
          }
        }
        return (locals.multiplier, amountToBurn);
      }
      locals.cyclesHeld++;
      if (locals.tierIndex == 0) {
        locals.tierIndex++;
        if (locals.tierIndex > isolate.tiersLength)
          return (locals.multiplier, amountToBurn);
        locals.tier = isolate.tiers[locals.tierIndex];
      }
      if (locals.cyclesHeld == locals.tier.cycles) {
        locals.multiplier = locals.tier.multiplier;
        locals.tierIndex++;

        isolate.lockCommitments[user] = 0;
        isolate.bonusesAccrued[user] = 0;
        if (locals.tierIndex > isolate.tiersLength)
          return (locals.multiplier, amountToBurn);
        locals.tier = isolate.tiers[locals.tierIndex];
      }
    }
    return (locals.multiplier, amountToBurn);
  }

  function _updateDailyStatsToLast(
    StakingControllerLib.Isolate storage isolate,
    address sender,
    uint256 weight,
    bool penalize,
    bool init
  ) internal returns (uint256 redeemable, uint256 bonuses) {
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[sender];
    StakingControllerLib.UserWeightChanges storage weightChange =
      isolate.weightChanges[sender];
    if (user.start == 0) init = true;
    {
      uint256 cycleChange = user.cyclesHeld;
      (user.cycleEnd, user.cyclesHeld) = ComputeCyclesHeldLib
        ._computeCyclesHeld(
        user.cycleEnd,
        isolate.cycleInterval,
        user.cyclesHeld,
        block.timestamp
      );
      if (user.cyclesHeld > 0 && user.cyclesHeld > cycleChange) {
        uint256 baseWeight = isolate.sCnfi.balanceOf(sender);
        for (uint256 i = user.cyclesHeld; i > cycleChange; i--) {
          weightChange.changes[i] = baseWeight;
        }
        weightChange.totalCyclesSeen = user.cyclesHeld;
      }
    }
    if (penalize || init) {
      weightChange.changes[user.cyclesHeld] = weight;
      user.start = block.timestamp;
    }
    uint256 multiplier = _determineDailyMultiplier(isolate, sender);
    
    if (init) user.multiplier = multiplier;
    if (user.lastDaySeen < isolate.currentDay) {
      (redeemable, bonuses) = _updateRedeemable(isolate, user, multiplier);
      user.cumulativeTotalWeight = isolate.cumulativeTotalWeight;
      user.cumulativeRewardWeight = 0;
      isolate.dailyBonusesAccrued[sender] = isolate.dailyBonusesAccrued[sender]
        .add(bonuses);
      user.claimed = user.claimed.add(redeemable);
      user.redeemable = user.redeemable.add(redeemable);
      user.lastDaySeen = isolate.currentDay;
    }
    /*
        {
            if (!init && user.multiplier != multiplier && user.multiplier > 0) {
                uint256 previousUserWeight =
                    user.weight;
                uint256 newUserWeight =
                    weight.mul(multiplier).div(uint256(1 ether));

                if (isolate.totalWeight == previousUserWeight)
                    isolate.totalWeight = newUserWeight;
                else
                    isolate.totalWeight = isolate
                        .totalWeight
                        .add(newUserWeight)
                        .sub(previousUserWeight);
            }
        }
	*/
    user.multiplier = multiplier;
    if (penalize) {
      _deductRewards(isolate, sender, weight);
      user.cycleEnd = block.timestamp + isolate.cycleInterval;
      user.cyclesHeld = 0;
      if (isolate.tiersLength > 0) {
        uint256 min = isolate.tiers[1].minimum;
        if (min > weight) weightChange.totalCyclesSeen = 0;
        else {
          weightChange.changes[weightChange.totalCyclesSeen] = weight;
        }
      } else {
        weightChange.totalCyclesSeen = 0;
      }
 
    }
  }

  function _recalculateDailyWeights(
    StakingControllerLib.Isolate storage isolate,
    address sender,
    uint256 weight,
    bool penalize
  ) internal {
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[sender];
    uint256 previousMultiplier = user.multiplier;
    if (previousMultiplier == 0) {
      previousMultiplier = 1 ether;
      user.multiplier = previousMultiplier;
      user.weight = isolate.sCnfi.balanceOf(sender);
    }
    uint256 prevWeight = user.weight;
    _updateDailyStatsToLast(isolate, sender, weight, penalize, false);
    user.weight = weight = weight.mul(user.multiplier).div(1 ether);
    isolate.lastTotalWeight = isolate.totalWeight;
    isolate.totalWeight = isolate.totalWeight.add(weight).sub(prevWeight);
    

    user.lastTotalWeight = isolate.totalWeight;
  }

  function _deductRewards(
    StakingControllerLib.Isolate storage isolate,
    address sender,
    uint256 weight
  ) internal {
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[sender];
    StakingControllerLib.Tier memory tier;
    if (user.commitment > 0) {
      tier = isolate.tiers[user.commitment];
      if (weight < tier.minimum && user.cyclesHeld < tier.cycles) {
        user.commitment = 0;
        (uint256 redeemable, uint256 toBurn) =
          _computeNewRedeemablePrincipalSplit(isolate, sender);
        isolate.dailyBonusesAccrued[sender] = 0;
        user.redeemable = redeemable;
        isolate.sCnfi.burn(sender, toBurn);
        user.multiplier = uint256(1 ether);
      }
    }
  }

  function _computeNewRedeemablePrincipalSplit(
    StakingControllerLib.Isolate storage isolate,
    address user
  ) internal view returns (uint256 newRedeemable, uint256 toBurn) {
    uint256 total =
      isolate.dailyBonusesAccrued[user]
        .mul(isolate.commitmentViolationPenalty)
        .div(uint256(1 ether));
    StakingControllerLib.DailyUser storage dailyUser = isolate.dailyUsers[user];
    uint256 _redeemable = dailyUser.redeemable;

    newRedeemable =
      dailyUser.redeemable -
      Math.min(dailyUser.redeemable, total);
    if (newRedeemable == 0) {
      toBurn = total - _redeemable;
    }
  }

  function _recalculateWeights(
    StakingControllerLib.Isolate storage isolate,
    address sender,
    uint256 oldBalance,
    uint256 newBalance,
    bool penalty
  ) internal {
    StakingControllerLib.RecalculateLocals memory locals;
    UpdateToLastImplLib._updateToLast(isolate, sender);
    StakingControllerLib.Cycle storage cycle =
      isolate.cycles[isolate.currentCycle];
    StakingControllerLib.User storage user = cycle.users[sender];
    //StakingControllerLib.User storage dailyUser = cycle.users[sender];
    user.start = block.timestamp;

    locals.currentWeight = user.currentWeight;
    if (oldBalance != newBalance) {
      if (locals.currentWeight == oldBalance) user.currentWeight = newBalance;
      else
        user.currentWeight = locals.currentWeight.add(newBalance).sub(
          oldBalance
        );
    }
    // _recalculateDailyWeights(isolate, sender, newBalance.mul(dailyUser.multiplier).div(uint256(1 ether)), penalty);
    locals.previousMultiplier = user.multiplier;
    locals.previousMinimumWeight = user.minimumWeight;
    locals.previousTotalWeight = cycle.totalWeight;
    if (
      user.daysClaimed - cycle.day - 1 > 0 && locals.previousMinimumWeight > 0
    ) {
      locals.totalInflated;
      locals.daysToRedeem;
      if (cycle.day - 1 > user.daysClaimed)
        locals.daysToRedeem = uint256(cycle.day - 1).sub(user.daysClaimed);
      locals.totalInflated = isolate.inflateBy.mul(locals.daysToRedeem);
      locals.previousRedeemable = user.redeemable;

      if (locals.totalInflated > 0) {
        locals.amt = locals
          .totalInflated
          .mul(locals.previousMinimumWeight)
          .mul(locals.previousMultiplier)
          .div(1 ether)
          .div(locals.previousTotalWeight);
        user.redeemable = locals.previousRedeemable.add(locals.amt);
        if (locals.previousMultiplier > 1 ether) {
          locals.bonus = locals
            .amt
            .mul(locals.previousMultiplier.sub(1 ether))
            .div(locals.previousMultiplier);
          isolate.bonusesAccrued[sender] = isolate.bonusesAccrued[sender].add(
            locals.bonus
          );
        }
        user.daysClaimed = cycle.day - 1;
      }
    }
    locals.minimumWeight = Math.min(user.minimumWeight, locals.currentWeight);
    (locals.multiplier, ) = _determineMultiplier(
      isolate,
      penalty,
      sender,
      newBalance
    );
    user.minimumWeight = locals.minimumWeight;
    locals.currentTotalWeight = cycle
      .totalWeight
      .add(locals.minimumWeight.mul(locals.multiplier).div(uint256(1 ether)))
      .sub(
      locals.previousMinimumWeight.mul(locals.previousMultiplier).div(
        uint256(1 ether)
      )
    );

    cycle.totalWeight = locals.currentTotalWeight;
    cycle.totalRawWeight = cycle
      .totalRawWeight
      .add(user.currentWeight.mul(locals.multiplier).div(1 ether))
      .sub(locals.currentWeight.mul(locals.previousMultiplier).div(1 ether));

    user.multiplier = locals.multiplier;
  }

  function _determineDailyMultiplier(
    StakingControllerLib.Isolate storage isolate,
    address sender
  ) internal returns (uint256 multiplier) {
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[sender];
    StakingControllerLib.UserWeightChanges storage weightChange =
      isolate.weightChanges[sender];
    StakingControllerLib.DetermineMultiplierLocals memory locals;
    locals.tierIndex = Math.max(user.commitment, user.currentTier);
    locals.tier = isolate.tiers[locals.tierIndex];
    locals.multiplier = locals.tierIndex == 0
      ? 1 ether
      : locals.tier.multiplier;
    multiplier = locals.multiplier;
    user.currentTier = 0;
    locals.minimum = uint256(~1);
    for (uint256 i = weightChange.totalCyclesSeen; i > 0; i--) {
      locals.minimum = Math.min(locals.minimum, weightChange.changes[i]);
      if (locals.minimum < locals.tier.minimum) {
        
        if (locals.tierIndex > 0 && locals.tierIndex > user.commitment)
          user.currentTier = --locals.tierIndex;
        locals.tier = isolate.tiers[locals.tierIndex];
        locals.multiplier = locals.tier.multiplier;
        return locals.multiplier;
      }
      user.currentTier = locals.tierIndex;
      locals.cyclesHeld++;
      if (locals.cyclesHeld >= locals.tier.cycles) {
        if (user.commitment == locals.tierIndex) {
          user.commitment = 0;
        }
        locals.tierIndex++;

        if (locals.tierIndex > isolate.tiersLength - 1) {
          return isolate.tiers[--locals.tierIndex].multiplier;
        }
        locals.tier = isolate.tiers[locals.tierIndex];

        locals.multiplier = locals.tier.multiplier;
      }
    }
    if(user.commitment == 0) {
      locals.tier = isolate.tiers[user.currentTier];
      multiplier = locals.tier.multiplier;
    }
  }
}
