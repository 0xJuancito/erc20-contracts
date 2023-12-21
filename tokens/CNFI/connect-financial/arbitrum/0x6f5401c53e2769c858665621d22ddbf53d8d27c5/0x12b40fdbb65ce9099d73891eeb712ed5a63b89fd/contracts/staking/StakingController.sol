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

contract StakingController is
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
  {}

  event RewardsClaimed(
    address indexed user,
    uint256 amountToRedeem,
    uint256 bonuses
  );

  function claimRewards()
    public
    onlyOwner
    returns (uint256 amountToRedeem, uint256 bonuses)
  {}

  function claimRewardsWithAmount(uint256 amount)
    public
    onlyOwner
    returns (uint256 amountToRedeem, uint256 bonuses)
  {}

  function restakeRewardsWithAmount(uint256 amount, uint256 tier)
    public
    onlyOwner
  {}

  function recalculateWeights(
    address sender,
    uint256 oldBalance,
    uint256 newBalance,
    bool penalty
  ) internal {}

  function stake(uint256 amount, uint256 commitmentTier) public {}

  function unstake(uint256 amount) public returns (uint256 withdrawable) {}
}
