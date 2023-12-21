// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {StakingControllerRedeploy as StakingController} from "./StakingControllerRedeploy.sol";
import {StakingControllerLib} from "./StakingControllerLib.sol";
import {UpdateToLastLib} from "./UpdateToLastLib.sol";
import {UpdateRedeemableLib} from "./UpdateRedeemableLib.sol";

contract StakingControllerTest is StakingController {
  function mintCnfi(address target, uint256 amount) public {
    isolate.cnfi.mint(target, amount);
  }

  function triggerNextCycle() public {
    _triggerCycle(true);
  }

  function triggerNextReward() public {
    _trackDailyRewards(true);
  }

  function trackDailyRewards() public {
    _trackDailyRewards(false);
  }

  function triggerCycle() public {
    _triggerCycle(false);
  }

  function updateCumulativeRewards(address user) public {
    _updateCumulativeRewards(user);
  }

  function updateToLast(address user) public {
    _updateToLast(user);
  }

  function updateWeightsWithMultiplier(address user) public {
    _updateWeightsWithMultiplier(user);
  }

  function updateDailyStatsToLast(address user) public {
    _updateDailyStatsToLast(user);
  }

  function triggerCycleUpdates() public {
    triggerCycle();
    trackDailyRewards();
  }

  function triggerUserUpdates(address sender) public {
    UpdateRedeemableLib.updateCumulativeRewards(isolate, sender);
    updateToLast(sender);
    updateWeightsWithMultiplier(sender);
    UpdateRedeemableLib.updateDailyStatsToLast(
      isolate,
      sender,
      0,
      false,
      false
    );
  }

  function triggerNextDailyCycle(address sender) public {
    uint256 prevCycleInterval = isolate.cycleInterval;
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[sender];
    user.cycleEnd = block.timestamp - 1;
    isolate.cycleInterval = 5;
    receiveCallback(sender, address(0x0));
    isolate.cycleInterval = prevCycleInterval;
    user.cycleEnd = block.timestamp + isolate.cycleInterval;
  }
}
