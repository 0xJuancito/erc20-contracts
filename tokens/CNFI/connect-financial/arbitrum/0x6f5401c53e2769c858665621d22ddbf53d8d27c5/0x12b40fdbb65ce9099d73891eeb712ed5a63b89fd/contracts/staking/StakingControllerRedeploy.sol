// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/Initializable.sol";
import {StakingControllerLib} from "./StakingControllerLib.sol";
import {ConnectToken as CNFI} from "../token/CNFI.sol";
import {sCNFI} from "../token/sCNFI.sol";
import {pCNFIFactoryLib} from "../token/lib/pCNFIFactoryLib.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {MathUpgradeable as Math} from "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import {pCNFI} from "../token/pCNFI.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {FactoryLib} from "../lib/FactoryLib.sol";
import {ICNFI} from "../interfaces/ICNFI.sol";
import {CNFITreasury} from "../treasury/CNFITreasury.sol";
import {ViewExecutor} from "../util/ViewExecutor.sol";
import {StakingControllerTemplate} from "./StakingControllerTemplate.sol";
import {UpdateToLastLib} from "./UpdateToLastLib.sol";
import {UpdateRedeemableLib} from "./UpdateRedeemableLib.sol";
import {GetDisplayTierImplLib} from "./GetDisplayTierImplLib.sol";
import {StakingEventsLib} from "./StakingEventsLib.sol";
import {CalculateRewardsLib} from "./CalculateRewardsLib.sol";
import {CalculateRewardsImplLib} from "./CalculateRewardsImplLib.sol";
import {RevertConstantsLib} from "../util/RevertConstantsLib.sol";
import {BancorFormulaLib} from "../math/BancorFormulaLib.sol";

contract StakingControllerRedeploy is
  StakingControllerTemplate,
  ViewExecutor,
  RevertConstantsLib
{
  using SafeMathUpgradeable for *;
  using BancorFormulaLib for *;

  function initialize(
    address _cnfi,
    address _sCnfi,
    address _cnfiTreasury
  ) public initializer {
    __Ownable_init_unchained();
    isolate.cnfi = ICNFI(_cnfi);
    isolate.pCnfiImplementation = Create2.deploy(
      0,
      pCNFIFactoryLib.getSalt(),
      pCNFIFactoryLib.getBytecode()
    );
    isolate.cnfiTreasury = CNFITreasury(_cnfiTreasury);
    isolate.sCnfi = sCNFI(_sCnfi);
    isolate.rewardInterval = 1 days;
    isolate.cycleInterval = 180 days;
  }

  function govern(
    uint256 _cycleInterval,
    uint256 _rewardInterval,
    uint256 _inflateBy,
    uint256 _inflatepcnfiBy,
    uint256 _baseUnstakePenalty,
    uint256 _commitmentViolationPenalty,
    uint256[] memory _multipliers,
    uint256[] memory _cycles,
    uint256[] memory _minimums
  ) public onlyOwner {
    if (_baseUnstakePenalty > 0)
      isolate.baseUnstakePenalty = _baseUnstakePenalty;
    if (_commitmentViolationPenalty > 0)
      isolate.commitmentViolationPenalty = _commitmentViolationPenalty;
    if (_cycleInterval > 0) {
      isolate.cycleInterval = _cycleInterval;
      isolate.nextCycleTime = block.timestamp + isolate.cycleInterval;
    }
    if (_rewardInterval > 0) {
      isolate.rewardInterval = _rewardInterval;
      isolate.nextTimestamp = block.timestamp + isolate.rewardInterval;
    }
    if (_inflateBy > 0) {
      if (_inflateBy != isolate.inflateBy) {
        isolate.inflateByChanged.push(isolate.currentDay);
        isolate.inflateByValues[isolate.currentDay] = StakingControllerLib
          .InflateByChanged(isolate.totalWeight, isolate.inflateBy);
      }
      isolate.inflateBy = _inflateBy;
    }
    if (_inflatepcnfiBy > 0) isolate.inflatepcnfiBy = _inflatepcnfiBy;
    isolate.tiersLength = _multipliers.length + 1;
    isolate.tiers[0].multiplier = uint256(1 ether);
    for (uint256 i = 0; i < _multipliers.length; i++) {
      isolate.tiers[i + 1] = StakingControllerLib.Tier(
        _multipliers[i],
        _minimums[i],
        _cycles[i]
      );
    }
  }

  function fillFirstCycle() public onlyOwner {
    _triggerCycle(true);
  }

  function _triggerCycle(bool force) internal {
    if (force || block.timestamp > isolate.nextCycleTime) {
      isolate.nextCycleTime = block.timestamp + isolate.cycleInterval;
      uint256 _currentCycle = ++isolate.currentCycle;
      isolate.cycles[_currentCycle].pCnfiToken = FactoryLib.create2Clone(
        isolate.pCnfiImplementation,
        uint256(
          keccak256(abi.encodePacked(pCNFIFactoryLib.getSalt(), _currentCycle))
        )
      );
      isolate.nextTimestamp = block.timestamp + isolate.rewardInterval;
      isolate.pCnfi = pCNFI(isolate.cycles[_currentCycle].pCnfiToken);
      isolate.pCnfi.initialize(_currentCycle);
      isolate.cycles[_currentCycle].day = 1;
      if (_currentCycle != 1) {
        isolate.cycles[_currentCycle].totalWeight = isolate
          .cycles[_currentCycle - 1]
          .totalRawWeight;
        isolate.cycles[_currentCycle].totalRawWeight = isolate
          .cycles[_currentCycle - 1]
          .totalRawWeight;
      }
    }
  }

  function determineMultiplier(address user, bool penaltyChange)
    internal
    returns (uint256)
  {
    uint256 currentBalance = isolate.sCnfi.balanceOf(user);
    (uint256 multiplier, uint256 amountToBurn) = UpdateRedeemableLib
      .determineMultiplier(isolate, penaltyChange, user, currentBalance);
    if (amountToBurn > 0) isolate.sCnfi.burn(user, amountToBurn);
    return multiplier;
  }

  function _updateToLast(address user) internal {
    UpdateToLastLib.updateToLast(isolate, user);
  }

  function _updateCumulativeRewards(address user) internal {
    UpdateRedeemableLib.updateCumulativeRewards(isolate, user);
  }

  function _updateWeightsWithMultiplier(address user)
    internal
    returns (uint256)
  {
    uint256 multiplier = determineMultiplier(user, false);

    return
      UpdateToLastLib.updateWeightsWithMultiplier(isolate, user, multiplier);
  }

  function _updateDailyStatsToLast(address user) internal {
    UpdateRedeemableLib.updateDailyStatsToLast(isolate, user, 0, false, false);
  }

  function receiveSingularCallback(address sender) public {
    if (sender != address(0x0)) {
      _trackDailyRewards(false);
      _triggerCycle(false);
      _updateCumulativeRewards(sender);
      _updateToLast(sender);
      _updateWeightsWithMultiplier(sender);
      _updateDailyStatsToLast(sender);
    }
  }

  function receiveCallback(address a, address b) public {
    receiveSingularCallback(a);
    receiveSingularCallback(b);
  }

  function calculateRewards(
    address _user,
    uint256 amount,
    bool isView
  ) internal returns (uint256 amountToRedeem, uint256 bonuses) {
    receiveCallback(_user, address(0x0));
    return CalculateRewardsLib.calculateRewards(isolate, _user, amount, isView);
  }

  function determineDailyMultiplier(address sender)
    internal
    returns (uint256 multiplier)
  {
    multiplier = UpdateRedeemableLib.determineDailyMultiplier(isolate, sender);
  }

  function _trackDailyRewards(bool force) internal {
    StakingControllerLib.Cycle storage cycle = isolate.cycles[
      isolate.currentCycle
    ];

    if (
      force || (!cycle.canUnstake && block.timestamp > isolate.nextTimestamp)
    ) {
      uint256 daysMissed = 1;
      if (block.timestamp > isolate.nextTimestamp) {
        daysMissed = block
          .timestamp
          .sub(isolate.nextTimestamp)
          .div(isolate.rewardInterval)
          .add(1);
      }
      isolate.nextTimestamp = block.timestamp + isolate.rewardInterval;
      cycle.reserved = cycle.reserved.add(isolate.inflateBy * daysMissed);
      isolate.pCnfi.mint(
        address(isolate.cnfiTreasury),
        isolate.inflatepcnfiBy * daysMissed
      );
      for (uint256 i = 0; i < daysMissed; i++) {
        cycle.cnfiRewards[cycle.day] = isolate.inflateBy;
        cycle.day++;
      }
      isolate.cumulativeTotalWeight = isolate.cumulativeTotalWeight.add(
        isolate.totalWeight * daysMissed
      );

      isolate.currentDay += daysMissed;
    }
  }

  function _claim(address user)
    public
    view
    returns (uint256 amountToRedeem, uint256 bonuses)
  {
    (amountToRedeem, bonuses) = CalculateRewardsImplLib._computeRewards(
      isolate,
      user
    );
  }

  event RewardsClaimed(
    address indexed user,
    uint256 amountToRedeem,
    uint256 bonuses
  );

  function claimRewards()
    public
    returns (uint256 amountToRedeem, uint256 bonuses)
  {
    return claimRewardsWithAmount(0);
  }

  function claimRewardsWithAmount(uint256 amount)
    public
    returns (uint256 amountToRedeem, uint256 bonuses)
  {
    (amountToRedeem, bonuses) = calculateRewards(msg.sender, amount, false);
    isolate.cnfi.transferFrom(
      address(isolate.cnfiTreasury),
      msg.sender,
      amountToRedeem
    );
    StakingEventsLib._emitRedeemed(msg.sender, amountToRedeem, bonuses);
  }

  function restakeRewardsWithAmount(uint256 amount, uint256 tier) public {
    (uint256 amountToRedeem, uint256 bonuses) = calculateRewards(
      msg.sender,
      amount,
      false
    );
    uint256 oldBalance = isolate.sCnfi.balanceOf(msg.sender);
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[
      msg.sender
    ];

    require(
      (oldBalance + amountToRedeem >= isolate.tiers[tier].minimum &&
        isolate.tiers[tier].minimum != 0) || tier == 0,
      "must provide more capital to commit to tier"
    );
    if (isolate.lockCommitments[msg.sender] <= tier)
      isolate.lockCommitments[msg.sender] = tier;
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
    recalculateWeights(msg.sender, oldBalance, newBalance, false);
  }

  function recalculateWeights(
    address sender,
    uint256 oldBalance,
    uint256 newBalance,
    bool penalty
  ) internal {
    UpdateRedeemableLib.recalculateDailyWeights(
      isolate,
      sender,
      newBalance,
      penalty
    );
    UpdateRedeemableLib.recalculateWeights(
      isolate,
      sender,
      oldBalance,
      newBalance,
      penalty
    );
  }

  function stake(uint256 amount, uint256 commitmentTier) public {
    require(commitmentTier < isolate.tiersLength);
    receiveCallback(msg.sender, address(0x0));
    uint256 oldBalance = isolate.sCnfi.balanceOf(msg.sender);
    uint256 newBalance = oldBalance.add(amount);
    isolate.cnfi.transferFrom(
      msg.sender,
      address(isolate.cnfiTreasury),
      amount
    );
    isolate.sCnfi.mint(msg.sender, amount);
    require(
      (oldBalance + amount >= isolate.tiers[commitmentTier].minimum &&
        isolate.tiers[commitmentTier].minimum != 0) || commitmentTier == 0,
      "must provide more capital to commit to tier"
    );
    if (commitmentTier >= isolate.dailyUsers[msg.sender].commitment)
      isolate.lockCommitments[msg.sender] = commitmentTier;
    bool isLocked = isolate.lockCommitments[msg.sender] > 0;
    StakingControllerLib.DailyUser storage user = isolate.dailyUsers[
      msg.sender
    ];
    if (commitmentTier >= user.commitment) {
      user.commitment = commitmentTier;
      if (user.commitment == 0) isolate.dailyBonusesAccrued[msg.sender] = 0;
    }
    commitmentTier = GetDisplayTierImplLib._getDisplayTier(
      isolate,
      commitmentTier,
      newBalance
    );
    StakingEventsLib._emitStaked(
      msg.sender,
      amount,
      commitmentTier - 1,
      isolate.tiers[commitmentTier].minimum,
      isLocked
    );
    recalculateWeights(msg.sender, oldBalance, newBalance, false);
  }

  function unstake(uint256 amount) public returns (uint256 withdrawable) {
    receiveCallback(msg.sender, address(0x0));
    uint256 oldBalance = isolate.sCnfi.balanceOf(msg.sender);
    uint256 newBalance;
    if (oldBalance > amount) newBalance = oldBalance.sub(amount);
    else newBalance = 0;

    uint256 beforeRecalculatedBalance = isolate.sCnfi.balanceOf(msg.sender);
    recalculateWeights(msg.sender, oldBalance, newBalance, true);
    uint256 currentBalance = isolate.sCnfi.balanceOf(msg.sender);
    uint256 amountLeft = Math.min(currentBalance, amount);
    isolate.sCnfi.burn(msg.sender, amountLeft);
    StakingEventsLib._emitUnstaked(
      msg.sender,
      amountLeft,
      beforeRecalculatedBalance -
        Math.min(beforeRecalculatedBalance, isolate.sCnfi.balanceOf(msg.sender))
    );
    isolate.cnfi.transferFrom(
      address(isolate.cnfiTreasury),
      msg.sender,
      amountLeft.mul(uint256(1 ether).sub(isolate.baseUnstakePenalty)).div(
        uint256(1 ether)
      )
    );
    withdrawable = amountLeft;
  }
}
