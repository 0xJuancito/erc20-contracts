// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./constant.sol";
import "./enum.sol";

//TitanX
/**@notice get batch mint ladder total count
 * @param minDay minimum mint length
 * @param maxDay maximum mint length, cap at 280
 * @param dayInterval day increase from previous mint length
 * @param countPerInterval number of mints per minth length
 * @return count total mints
 */
function getBatchMintLadderCount(
    uint256 minDay,
    uint256 maxDay,
    uint256 dayInterval,
    uint256 countPerInterval
) pure returns (uint256 count) {
    if (maxDay > minDay) {
        count = (((maxDay - minDay) / dayInterval) + 1) * countPerInterval;
    }
}

/** @notice get incentive fee in 4 decimals scaling
 * @return fee fee
 */
function getIncentiveFeePercent() pure returns (uint256) {
    return (INCENTIVE_FEE_PERCENT * 1e4) / INCENTIVE_FEE_PERCENT_BASE;
}

/** @notice get batch mint cost
 * @param mintPower mint power (1 - 100)
 * @param count number of mints
 * @return mintCost total mint cost
 */
function getBatchMintCost(
    uint256 mintPower,
    uint256 count,
    uint256 mintCost
) pure returns (uint256) {
    return (mintCost * mintPower * count) / MAX_MINT_POWER_CAP;
}

//MintInfo

/** @notice the formula to calculate mint reward at create new mint
 * @param mintPower mint power 1 - 100
 * @param numOfDays mint length 1 - 280
 * @param mintableTitan current contract day mintable titan
 * @param EAABonus current contract day EAA Bonus
 * @param burnAmpBonus user burn amplifier bonus from getUserBurnAmplifierBonus(user)
 * @return reward base titan amount
 */
function calculateMintReward(
    uint256 mintPower,
    uint256 numOfDays,
    uint256 mintableTitan,
    uint256 EAABonus,
    uint256 burnAmpBonus
) pure returns (uint256 reward) {
    uint256 baseReward = (mintableTitan * mintPower * numOfDays);
    if (numOfDays != 1)
        baseReward -= (baseReward * MINT_DAILY_REDUCTION * (numOfDays - 1)) / PERCENT_BPS;

    reward = baseReward;
    if (EAABonus != 0) {
        //EAA Bonus has 1e6 scaling, so here divide by 1e6
        reward += ((baseReward * EAABonus) / 100 / SCALING_FACTOR_1e6);
    }

    if (burnAmpBonus != 0) {
        //burnAmpBonus has 1e18 scaling
        reward += (baseReward * burnAmpBonus) / 100 / SCALING_FACTOR_1e18;
    }

    reward /= MAX_MINT_POWER_CAP;
}

/** @notice the formula to calculate bonus reward
 * heavily influenced by the difference between current global mint power and user mint's global mint power
 * @param mintPowerBonus mint power bonus from mintinfo
 * @param mintPower mint power 1 - 100 from mintinfo
 * @param gMintPower global mint power from mintinfo
 * @param globalMintPower current global mint power
 * @return bonus bonus amount in titan
 */
function calculateMintPowerBonus(
    uint256 mintPowerBonus,
    uint256 mintPower,
    uint256 gMintPower,
    uint256 globalMintPower
) pure returns (uint256 bonus) {
    if (globalMintPower <= gMintPower) return 0;
    bonus = (((mintPowerBonus * mintPower * (globalMintPower - gMintPower)) * SCALING_FACTOR_1e18) /
        MAX_MINT_POWER_CAP);
}

/** @notice Return max mint length
 * @return maxMintLength max mint length
 */
function getMaxMintDays() pure returns (uint256) {
    return MAX_MINT_LENGTH;
}

/** @notice Return max mints per wallet
 * @return maxMintPerWallet max mints per wallet
 */
function getMaxMintsPerWallet() pure returns (uint256) {
    return MAX_MINT_PER_WALLET;
}

/**
 * @dev Return penalty percentage based on number of days late after the grace period of 7 days
 * @param secsLate seconds late (block timestamp - maturity timestamp)
 * @return penalty penalty in percentage
 */
function calculateClaimMintPenalty(uint256 secsLate) pure returns (uint256 penalty) {
    if (secsLate <= CLAIM_MINT_GRACE_PERIOD * SECONDS_IN_DAY) return 0;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 1) * SECONDS_IN_DAY) return 1;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 2) * SECONDS_IN_DAY) return 3;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 3) * SECONDS_IN_DAY) return 8;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 4) * SECONDS_IN_DAY) return 17;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 5) * SECONDS_IN_DAY) return 35;
    if (secsLate <= (CLAIM_MINT_GRACE_PERIOD + 6) * SECONDS_IN_DAY) return 72;
    return 99;
}

//StakeInfo

error TitanX_AtLeastHalfMaturity();

/** @notice get max stake length
 * @return maxStakeLength max stake length
 */
function getMaxStakeLength() pure returns (uint256) {
    return MAX_STAKE_LENGTH;
}

/** @notice calculate shares and shares bonus
 * @param amount titan amount
 * @param noOfDays stake length
 * @param shareRate current contract share rate
 * @return shares calculated shares in 18 decimals
 */
function calculateShares(
    uint256 amount,
    uint256 noOfDays,
    uint256 shareRate
) pure returns (uint256) {
    uint256 shares = amount;
    shares += (shares * calculateShareBonus(amount, noOfDays)) / SCALING_FACTOR_1e11;
    shares /= (shareRate / SCALING_FACTOR_1e18);
    return shares;
}

/** @notice calculate share bonus
 * @param amount titan amount
 * @param noOfDays stake length
 * @return shareBonus calculated shares bonus in 11 decimals
 */
function calculateShareBonus(uint256 amount, uint256 noOfDays) pure returns (uint256 shareBonus) {
    uint256 cappedExtraDays = noOfDays <= LPB_MAX_DAYS ? noOfDays : LPB_MAX_DAYS;
    uint256 cappedStakedTitan = amount <= BPB_MAX_TITAN ? amount : BPB_MAX_TITAN;
    shareBonus =
        ((cappedExtraDays * SCALING_FACTOR_1e11) / LPB_PER_PERCENT) +
        ((cappedStakedTitan * SCALING_FACTOR_1e11) / BPB_PER_PERCENT);
    return shareBonus;
}

/** @notice calculate end stake penalty
 * @param stakeStartTs start stake timestamp
 * @param maturityTs  maturity timestamp
 * @param currentBlockTs current block timestamp
 * @param action end stake or burn stake
 * @return penalty penalty in percentage
 */
function calculateEndStakePenalty(
    uint256 stakeStartTs,
    uint256 maturityTs,
    uint256 currentBlockTs,
    StakeAction action
) view returns (uint256) {
    //Matured, then calculate and return penalty
    if (currentBlockTs > maturityTs) {
        uint256 lateSec = currentBlockTs - maturityTs;
        uint256 gracePeriodSec = END_STAKE_GRACE_PERIOD * SECONDS_IN_DAY;
        if (lateSec <= gracePeriodSec) return 0;
        return max((min((lateSec - gracePeriodSec), 1) / SECONDS_IN_DAY) + 1, 99);
    }

    //burn stake is excluded from penalty
    //if not matured and action is burn stake then return 0
    if (action == StakeAction.BURN) return 0;

    //Emergency End Stake
    //Not allow to EES below 50% maturity
    if (block.timestamp < stakeStartTs + (maturityTs - stakeStartTs) / 2)
        revert TitanX_AtLeastHalfMaturity();

    //50% penalty for EES before maturity timestamp
    return 50;
}

//a - input to check against b
//b - minimum number
function min(uint256 a, uint256 b) pure returns (uint256) {
    if (a > b) return a;
    return b;
}

//a - input to check against b
//b - maximum number
function max(uint256 a, uint256 b) pure returns (uint256) {
    if (a > b) return b;
    return a;
}
