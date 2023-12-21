// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { CNFITreasury } from "../treasury/CNFITreasury.sol";
import { ICNFI } from "../interfaces/ICNFI.sol";
import { pCNFI } from "../token/pCNFI.sol";
import { sCNFI } from "../token/sCNFI.sol";

contract StakingControllerLib {
    struct Isolate {
      uint256 currentCycle;
      CNFITreasury cnfiTreasury;
      ICNFI cnfi;
      sCNFI sCnfi;
      pCNFI pCnfi;
      uint256 nextCycleTime;
      uint256 cycleInterval;
      uint256 nextTimestamp;
      uint256 inflateBy;
      uint256 inflatepcnfiBy;
      uint256 rewardInterval;
      uint256 tiersLength;
      uint256 baseUnstakePenalty;
      uint256 commitmentViolationPenalty;
      uint256 totalWeight;
      uint256 lastTotalWeight;
      uint256 cumulativeTotalWeight;
      mapping(uint256 => StakingControllerLib.Cycle) cycles;
      mapping(uint256 => StakingControllerLib.Tier) tiers;
      mapping(address => uint256) lockCommitments;
      mapping(address => uint256) bonusesAccrued;
      mapping(address => uint256) dailyBonusesAccrued;
      mapping(address => StakingControllerLib.UserWeightChanges) weightChanges;
      mapping(address => StakingControllerLib.DailyUser) dailyUsers;
      uint256[] inflateByChanged;
      mapping(uint256 => StakingControllerLib.InflateByChanged) inflateByValues;
      address pCnfiImplementation;
      uint256 currentDay;
    }
    struct User {
        uint256 currentWeight;
        uint256 minimumWeight;
        uint256 dailyWeight;
        uint256 multiplier;
        uint256 redeemable;
        uint256 daysClaimed;
        uint256 start;
        bool seen;
        uint256 currentTier;
        uint256 cyclesHeld;
    }
    struct DailyUser {
        uint256 multiplier;
        uint256 cycleEnd;
        uint256 cyclesHeld;
        uint256 redeemable;
        uint256 start;
        uint256 weight;
        uint256 claimed;
        uint256 commitment;
        uint256 lastDaySeen;
        uint256 cumulativeTotalWeight;
        uint256 cumulativeRewardWeight;
        uint256 lastTotalWeight;
        uint256 currentTier;
    }
    struct DetermineMultiplierLocals {
        uint256 scnfiBalance;
        uint256 minimum;
        uint256 tierIndex;
        Tier tier;
        uint256 cyclesHeld;
        uint256 multiplier;
    }
    struct DetermineRewardLocals {
        uint256 lastDaySeen;
        uint256 redeemable;
        uint256 totalWeight;
        uint256 multiplier;
        uint256 weight;
        uint256 rawWeight;
        uint256 totalRawWeight;
    }
    struct ReturnStats {
        uint256 lockCommitment;
        uint256 totalStakedInProtocol;
        uint256 cnfiReleasedPerDay;
        uint256 staked;
        uint256 currentCnfiBalance;
        uint256 unstakePenalty;
        uint256 redeemable;
        uint256 bonuses;
        uint256 apy;
        uint256 commitmentViolationPenalty;
        uint256 basePenalty;
        uint256 totalWeight;
        uint256 cycleChange;
        uint256 totalCyclesSeen;
    }
    struct Cycle {
        uint256 totalWeight;
        uint256 totalRawWeight;
        address pCnfiToken;
        uint256 reserved;
        uint256 day;
        uint256 inflateBy;
        mapping(address => User) users;
        mapping(uint256 => uint256) cnfiRewards;
        mapping(uint256 => uint256) pcnfiRewards;
        bool canUnstake;
    }
    struct Tier {
        uint256 multiplier;
        uint256 minimum;
        uint256 cycles;
    }
    struct EncodeableCycle {
        uint256 totalWeight;
        uint256 totalRawWeight;
        address pCnfiToken;
        uint256 reserved;
        uint256 day;
        bool canUnstake;
        uint256 lastCycleSeen;
        uint256 currentCycle;
    }
    struct UpdateLocals {
        uint256 multiplier;
        uint256 weight;
        uint256 prevMul;
        uint256 prevRes;
        uint256 prevRawRes;
        uint256 nextRes;
        uint256 nextRawRes;
    }
    struct RecalculateLocals {
        uint256 currentWeight;
        uint256 previousMultiplier;
        uint256 previousMinimumWeight;
        uint256 previousTotalWeight;
        uint256 totalInflated;
        uint256 daysToRedeem;
        uint256 previousRedeemable;
        uint256 amt;
        uint256 bonus;
        uint256 minimumWeight;
        uint256 multiplier;
        uint256 currentTotalWeight;
    }
    struct InflateByChanged {
        uint256 totalWeight;
        uint256 previousAmount;
    }
    struct DetermineInflateLocals {
        uint256 totalWeight;
        uint256 lastDaySeen;
        uint256 dayDifference;
        InflateByChanged changed;
        uint256 tempRedeemable;
        uint256 redeemable;
        uint256 daysToClaim;
        uint256 lastDayInEpoch;
        uint256 dayChanged;
        uint256 tempBonus;
        uint256 lastDayChanged;
    }
    struct UserWeightChanges {
        mapping(uint256 => uint256) changes;
        uint256 totalCyclesSeen;
    }
}
