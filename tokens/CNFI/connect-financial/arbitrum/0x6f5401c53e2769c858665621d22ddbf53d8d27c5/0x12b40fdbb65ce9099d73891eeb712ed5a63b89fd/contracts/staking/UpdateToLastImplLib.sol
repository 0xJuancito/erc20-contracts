// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import { StakingControllerLib } from './StakingControllerLib.sol';
import {
  SafeMathUpgradeable
} from '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';
import {
  MathUpgradeable as Math
} from '@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol';
import { GetDisplayTierLib } from "./GetDisplayTierLib.sol";

library UpdateToLastImplLib {
  using SafeMathUpgradeable for *;
  struct UpdateToLastLocals {
    uint256 cycleNumber;
    uint256 weight;
    uint256 multiplier;
    uint256 lastDaySeen;
    uint256 redeemable;
    uint256 totalWeight;
    uint256 daysToRedeem;
    uint256 bonus;
    uint256 i;
  }
  function _updateToLast(
    StakingControllerLib.Isolate storage isolate,
    address user
  ) internal {
    UpdateToLastLocals memory locals;
    StakingControllerLib.Cycle storage cycle = isolate.cycles[isolate.currentCycle];
    if (cycle.users[user].seen) return;
    StakingControllerLib.Cycle storage ptr = cycle;
    locals.cycleNumber = isolate.currentCycle;
    while (!ptr.users[user].seen && locals.cycleNumber > 0) {
      ptr = isolate.cycles[--locals.cycleNumber];

      if (ptr.users[user].seen) {
        locals.weight = ptr.users[user].currentWeight;
        locals.multiplier = ptr.users[user].multiplier;
        cycle.users[user].seen = true;
        cycle.users[user].currentWeight = locals.weight;
        cycle.users[user].minimumWeight = locals.weight;
        cycle.users[user].multiplier = locals.multiplier;
        cycle.users[user].redeemable = ptr.users[user].redeemable;
        cycle.users[user].start = ptr.users[user].start;
        locals.lastDaySeen = ptr.users[user].daysClaimed;
        locals.redeemable = 0;
        locals.totalWeight = ptr.totalWeight;

        if (locals.totalWeight > 0 && ptr.reserved > 0) {
          locals.daysToRedeem = 0;
          if (ptr.day - 1 > locals.lastDaySeen)
            locals.daysToRedeem = uint256(ptr.day - 1).sub(locals.lastDaySeen);
          locals.redeemable = locals.daysToRedeem.mul(isolate.inflateBy);
          locals.redeemable = locals
            .redeemable
            .mul(locals.weight)
            .mul(locals.multiplier)
            .div(locals.totalWeight)
            .div(1 ether);
          if (locals.multiplier > 1 ether) {
            locals.bonus = uint256(locals.multiplier.sub(1 ether))
              .mul(locals.redeemable)
              .div(locals.multiplier);
            isolate.bonusesAccrued[user] = isolate.bonusesAccrued[user].add(locals.bonus);
          }
          cycle.users[user].redeemable = cycle.users[user].redeemable.add(
            locals.redeemable
          );
        }

        for (
          locals.i = locals.cycleNumber + 1;
          locals.i < isolate.currentCycle;
          locals.i++
        ) {
          ptr = isolate.cycles[locals.i];
          locals.totalWeight = ptr.totalWeight;
          ptr.users[user].minimumWeight = locals.weight;
          ptr.users[user].multiplier = locals.multiplier;
          if (locals.totalWeight > 0 && ptr.reserved > 0) {
            locals.redeemable = ptr
              .reserved
              .mul(locals.weight)
              .mul(locals.multiplier)
              .div(ptr.totalWeight)
              .div(1 ether);
            cycle.users[user].redeemable = cycle.users[user].redeemable.add(
              locals.redeemable
            );
          }
        }

        return;
      }
    }
    cycle.users[user].seen = true;
    cycle.users[user].multiplier = 1 ether;
  }

  function _updateWeightsWithMultiplier(
    StakingControllerLib.Isolate storage isolate,
    address user,
    uint256 multiplier
  ) internal returns (uint256) {
    StakingControllerLib.Cycle storage cycle = isolate.cycles[isolate.currentCycle];
    StakingControllerLib.User storage _sender = cycle.users[user];
    StakingControllerLib.UpdateLocals memory locals;
    locals.multiplier = multiplier;
    locals.weight = Math.min(_sender.minimumWeight, _sender.currentWeight);
    locals.prevMul = _sender.multiplier;
    locals.prevRes = locals.weight.mul(locals.prevMul).div(1 ether);
    locals.prevRawRes = _sender.currentWeight.mul(locals.prevMul).div(1 ether);
    locals.nextRes = locals.weight.mul(locals.multiplier).div(1 ether);
    locals.nextRawRes = _sender.currentWeight.mul(locals.multiplier).div(
      1 ether
    );
    if (locals.multiplier != _sender.multiplier) {
      _sender.multiplier = locals.multiplier;
      if (cycle.totalWeight == locals.prevRes)
        cycle.totalWeight = locals.nextRes;
      else
        cycle.totalWeight = cycle.totalWeight.sub(locals.prevRes).add(
          locals.nextRes
        );
      if (cycle.totalRawWeight == locals.prevRawRes)
        cycle.totalRawWeight = locals.nextRawRes;
      else
        cycle.totalRawWeight = cycle.totalRawWeight.sub(locals.prevRawRes).add(
          locals.nextRawRes
        );
    }
    return locals.multiplier;
  }
}
