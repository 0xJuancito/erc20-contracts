// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import { StakingControllerLib } from "./StakingControllerLib.sol";
import { GetDisplayTierImplLib } from "./GetDisplayTierImplLib.sol";
import { UpdateRedeemableImplLib } from "./UpdateRedeemableLib.sol";
import { StakingEventsLib } from "./StakingEventsLib.sol";
import { CalculateRewardsImplLib } from "./CalculateRewardsImplLib.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { MathUpgradeable as Math } from "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";

library RestakeRewardsLib {
  using SafeMathUpgradeable for *;
  function restakeRewardsWithAmount(StakingControllerLib.Isolate storage isolate, uint256 amount, uint256 tier) external {
    _restakeRewardsWithAmount(isolate, amount, tier);
  }
  function _restakeRewardsWithAmount(StakingControllerLib.Isolate storage isolate, uint256 amount, uint256 tier) internal {
    (uint256 amountToRedeem, uint256 bonuses) =
      CalculateRewardsImplLib._calculateRewards(isolate, msg.sender, amount, false);
    uint256 oldBalance = isolate.sCnfi.balanceOf(msg.sender);
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[msg.sender];

    require(
      (oldBalance + amountToRedeem >= isolate.tiers[tier].minimum &&
        isolate.tiers[tier].minimum != 0) || tier == 0,
      'must provide more capital to commit to tier'
    );
    if (isolate.lockCommitments[msg.sender] <= tier) isolate.lockCommitments[msg.sender] = tier;
    if (user.commitment <= tier) user.commitment = tier;

    bool timeLocked = isolate.lockCommitments[msg.sender] > 0;
    uint256 newBalance = oldBalance.add(amountToRedeem);
    isolate.sCnfi.mint(msg.sender, amountToRedeem);
    StakingEventsLib._emitRedeemed(msg.sender, amountToRedeem, bonuses);
    tier = GetDisplayTierImplLib._getDisplayTier(isolate, tier, newBalance);
    StakingEventsLib._emitStaked(
      msg.sender,
      amountToRedeem,
      tier,
      isolate.tiers[tier].minimum,
      timeLocked
    );
    UpdateRedeemableImplLib._recalculateWeights(isolate, msg.sender, oldBalance, newBalance, false);
  }
}
