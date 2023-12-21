// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {
  SafeMathUpgradeable
} from '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';
import { CalculateRewardsImplLib } from './CalculateRewardsImplLib.sol';
import { StakingControllerLib } from './StakingControllerLib.sol';

library CalculateRewardsLib {
  using SafeMathUpgradeable for *;

  function calculateRewards(
    StakingControllerLib.Isolate storage isolate,
    address _user,
    uint256 amt,
    bool isView
  ) external returns (uint256 amountToRedeem, uint256 bonuses) {
    (amountToRedeem, bonuses) = CalculateRewardsImplLib._calculateRewards(
      isolate,
      _user,
      amt,
      isView
    );
  }
}
