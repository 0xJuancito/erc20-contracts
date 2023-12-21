// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../libs/enum.sol";
import "../libs/constant.sol";

abstract contract GlobalInfo {
    //Variables
    //deployed timestamp
    uint256 private immutable i_genesisTs;

    /** @dev track current contract day */
    uint256 private s_currentContractDay;
    /** @dev shareRate starts 800 ether and increases capped at 2800 ether, uint72 has enough size */
    uint72 private s_currentshareRate;
    /** @dev mintCost starts 0.2 ether increases and capped at 1 ether, uint64 has enough size */
    uint64 private s_currentMintCost;
    /** @dev mintableTitan starts 8m ether decreases and capped at 800 ether, uint96 has enough size */
    uint96 private s_currentMintableTitan;
    /** @dev mintPowerBonus starts 350_000_000 and decreases capped at 35_000, uint32 has enough size */
    uint32 private s_currentMintPowerBonus;
    /** @dev EAABonus starts 10_000_000 and decreases to 0, uint32 has enough size */
    uint32 private s_currentEAABonus;

    /** @dev track if any of the cycle day 8, 28, 90, 369, 888 has payout triggered succesfully
     * this is used in end stake where either the shares change should be tracked in current/next payout cycle
     */
    PayoutTriggered private s_isGlobalPayoutTriggered;

    /** @dev track payouts based on every cycle day 8, 28, 90, 369, 888 when distributeETH() is called */
    mapping(uint256 => uint256) private s_cyclePayouts;

    /** @dev track payout index for each cycle day, increased by 1 when triggerPayouts() is called succesfully
     *  eg. curent index is 2, s_cyclePayoutIndex[DAY8] = 2 */
    mapping(uint256 => uint256) private s_cyclePayoutIndex;

    /** @dev track payout info (day and payout per share) for each cycle day
     * eg. s_cyclePayoutIndex is 2,
     *  s_CyclePayoutPerShare[DAY8][2].day = 8
     * s_CyclePayoutPerShare[DAY8][2].payoutPerShare = 0.1
     */
    mapping(uint256 => mapping(uint256 => CycleRewardPerShare)) private s_cyclePayoutPerShare;

    /** @dev track user last payout reward claim index for cycleIndex, burnCycleIndex and sharesIndex
     * so calculation would start from next index instead of the first index
     * [address][DAY8].cycleIndex = 1
     * [address][DAY8].burnCycleIndex = 1
     * [address][DAY8].sharesIndex = 2
     * cycleIndex is the last stop in s_cyclePayoutPerShare
     * sharesIndex is the last stop in s_addressIdToActiveShares
     */
    mapping(address => mapping(uint256 => UserCycleClaimIndex))
        private s_addressCycleToLastClaimIndex;

    /** @dev track when is the next cycle payout day for each cycle day
     * eg. s_nextCyclePayoutDay[DAY8] = 8
     *     s_nextCyclePayoutDay[DAY28] = 28
     */
    mapping(uint256 => uint256) s_nextCyclePayoutDay;

    //structs
    struct CycleRewardPerShare {
        uint256 day;
        uint256 payoutPerShare;
    }

    struct UserCycleClaimIndex {
        uint96 cycleIndex;
        uint96 burnCycleIndex;
        uint64 sharesIndex;
    }

    //event
    event GlobalDailyUpdateStats(
        uint256 indexed day,
        uint256 indexed mintCost,
        uint256 indexed shareRate,
        uint256 mintableTitan,
        uint256 mintPowerBonus,
        uint256 EAABonus
    );

    /** @dev Update variables in terms of day, modifier is used in all external/public functions (exclude view)
     * Every interaction to the contract would run this function to update variables
     */
    modifier dailyUpdate() {
        _dailyUpdate();
        _;
    }

    constructor() {
        i_genesisTs = block.timestamp;
        s_currentContractDay = 1;
        s_currentMintCost = uint64(START_MAX_MINT_COST);
        s_currentMintableTitan = uint96(START_MAX_MINTABLE_PER_DAY);
        s_currentshareRate = uint72(START_SHARE_RATE);
        s_currentMintPowerBonus = uint32(START_MINTPOWER_INCREASE_BONUS);
        s_currentEAABonus = uint32(EAA_START);
        s_nextCyclePayoutDay[DAY8] = DAY8;
        s_nextCyclePayoutDay[DAY28] = DAY28;
        s_nextCyclePayoutDay[DAY90] = DAY90;
        s_nextCyclePayoutDay[DAY369] = DAY369;
        s_nextCyclePayoutDay[DAY888] = DAY888;
    }

    /** @dev calculate and update variables daily and reset triggers flag */
    function _dailyUpdate() private {
        uint256 currentContractDay = s_currentContractDay;
        uint256 currentBlockDay = ((block.timestamp - i_genesisTs) / 1 days) + 1;

        if (currentBlockDay > currentContractDay) {
            //get last day info ready for calculation
            uint256 newMintCost = s_currentMintCost;
            uint256 newShareRate = s_currentshareRate;
            uint256 newMintableTitan = s_currentMintableTitan;
            uint256 newMintPowerBonus = s_currentMintPowerBonus;
            uint256 newEAABonus = s_currentEAABonus;
            uint256 dayDifference = currentBlockDay - currentContractDay;

            /** Reason for a for loop to update Mint supply
             * Ideally, user interaction happens daily, so Mint supply is synced in every day
             *      (cylceDifference = 1)
             * However, if there's no interaction for more than 1 day, then
             *      Mint supply isn't updated correctly due to cylceDifference > 1 day
             * Eg. 2 days of no interaction, then interaction happens in 3rd day.
             *     It's incorrect to only decrease the Mint supply one time as now it's in 3rd day.
             *   And if this happens, there will be no tracked data for the skipped days as not needed
             */
            for (uint256 i; i < dayDifference; i++) {
                newMintCost = (newMintCost * DAILY_MINT_COST_INCREASE_STEP) / PERCENT_BPS;
                newShareRate = (newShareRate * DAILY_SHARE_RATE_INCREASE_STEP) / PERCENT_BPS;
                newMintableTitan =
                    (newMintableTitan * DAILY_SUPPLY_MINTABLE_REDUCTION) /
                    PERCENT_BPS;
                newMintPowerBonus =
                    (newMintPowerBonus * DAILY_MINTPOWER_INCREASE_BONUS_REDUCTION) /
                    PERCENT_BPS;

                if (newMintCost > 1 ether) {
                    newMintCost = CAPPED_MAX_MINT_COST;
                }

                if (newShareRate > CAPPED_MAX_RATE) newShareRate = CAPPED_MAX_RATE;

                if (newMintableTitan < CAPPED_MIN_DAILY_TITAN_MINTABLE) {
                    newMintableTitan = CAPPED_MIN_DAILY_TITAN_MINTABLE;
                }

                if (newMintPowerBonus < CAPPED_MIN_MINTPOWER_BONUS) {
                    newMintPowerBonus = CAPPED_MIN_MINTPOWER_BONUS;
                }

                if (currentBlockDay <= MAX_BONUS_DAY) {
                    newEAABonus -= EAA_BONUSE_FIXED_REDUCTION_PER_DAY;
                } else {
                    newEAABonus = EAA_END;
                }

                emit GlobalDailyUpdateStats(
                    ++currentContractDay,
                    newMintCost,
                    newShareRate,
                    newMintableTitan,
                    newMintPowerBonus,
                    newEAABonus
                );
            }

            s_currentMintCost = uint64(newMintCost);
            s_currentshareRate = uint72(newShareRate);
            s_currentMintableTitan = uint96(newMintableTitan);
            s_currentMintPowerBonus = uint32(newMintPowerBonus);
            s_currentEAABonus = uint32(newEAABonus);
            s_currentContractDay = currentBlockDay;
            s_isGlobalPayoutTriggered = PayoutTriggered.NO;
        }
    }

    /** @dev first created shares will start from the last payout index + 1 (next cycle payout)
     * as first shares will always disqualified from past payouts
     * reduce gas cost needed to loop from first index
     * @param user user address
     * @param isFirstShares flag to only initialize when address is fresh wallet
     */
    function _initFirstSharesCycleIndex(address user, uint256 isFirstShares) internal {
        if (isFirstShares == 1) {
            if (s_cyclePayoutIndex[DAY8] != 0) {
                s_addressCycleToLastClaimIndex[user][DAY8].cycleIndex = uint96(
                    s_cyclePayoutIndex[DAY8] + 1
                );

                s_addressCycleToLastClaimIndex[user][DAY28].cycleIndex = uint96(
                    s_cyclePayoutIndex[DAY28] + 1
                );

                s_addressCycleToLastClaimIndex[user][DAY90].cycleIndex = uint96(
                    s_cyclePayoutIndex[DAY90] + 1
                );

                s_addressCycleToLastClaimIndex[user][DAY369].cycleIndex = uint96(
                    s_cyclePayoutIndex[DAY369] + 1
                );

                s_addressCycleToLastClaimIndex[user][DAY888].cycleIndex = uint96(
                    s_cyclePayoutIndex[DAY888] + 1
                );
            }
        }
    }

    /** @dev first created shares will start from the last payout index + 1 (next cycle payout)
     * as first shares will always disqualified from past payouts
     * reduce gas cost needed to loop from first index
     * @param cycleNo cylce day 8, 28, 90, 369, 888
     * @param reward total accumulated reward in cycle day 8, 28, 90, 369, 888
     * @param globalActiveShares global active shares
     * @return index return latest current cycleIndex
     */
    function _calculateCycleRewardPerShare(
        uint256 cycleNo,
        uint256 reward,
        uint256 globalActiveShares
    ) internal returns (uint256 index) {
        s_cyclePayouts[cycleNo] = 0;
        index = ++s_cyclePayoutIndex[cycleNo];
        //add 18 decimals to reward for better precision in calculation
        s_cyclePayoutPerShare[cycleNo][index].payoutPerShare =
            (reward * SCALING_FACTOR_1e18) /
            globalActiveShares;
        s_cyclePayoutPerShare[cycleNo][index].day = getCurrentContractDay();
    }

    /** @dev update with the last index where a user has claimed the payout reward
     * @param user user address
     * @param cycleNo cylce day 8, 28, 90, 369, 888
     * @param userClaimCycleIndex last claimed cycle index
     * @param userClaimSharesIndex last claimed shares index
     */
    function _updateUserClaimIndexes(
        address user,
        uint256 cycleNo,
        uint256 userClaimCycleIndex,
        uint256 userClaimSharesIndex
    ) internal {
        if (userClaimCycleIndex != s_addressCycleToLastClaimIndex[user][cycleNo].cycleIndex)
            s_addressCycleToLastClaimIndex[user][cycleNo].cycleIndex = uint96(userClaimCycleIndex);

        if (userClaimSharesIndex != s_addressCycleToLastClaimIndex[user][cycleNo].sharesIndex)
            s_addressCycleToLastClaimIndex[user][cycleNo].sharesIndex = uint64(
                userClaimSharesIndex
            );
    }

    /** @dev update with the last index where a user has claimed the burn payout reward
     * @param user user address
     * @param cycleNo cylce day 8, 28, 90, 369, 888
     * @param userClaimBurnCycleIndex last claimed burn cycle index
     */
    function _updateUserBurnCycleClaimIndex(
        address user,
        uint256 cycleNo,
        uint256 userClaimBurnCycleIndex
    ) internal {
        if (userClaimBurnCycleIndex != s_addressCycleToLastClaimIndex[user][cycleNo].burnCycleIndex)
            s_addressCycleToLastClaimIndex[user][cycleNo].burnCycleIndex = uint96(
                userClaimBurnCycleIndex
            );
    }

    /** @dev set to YES when any of the cycle days payout is triggered
     * reset to NO in new contract day
     */
    function _setGlobalPayoutTriggered() internal {
        s_isGlobalPayoutTriggered = PayoutTriggered.YES;
    }

    /** @dev add reward into cycle day 8, 28, 90, 369, 888 pool
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @param reward reward from distributeETH()
     */
    function _setCyclePayoutPool(uint256 cycleNo, uint256 reward) internal {
        s_cyclePayouts[cycleNo] += reward;
    }

    /** @dev calculate and update the next payout day for specified cycleNo
     * the formula will update the payout day based on current contract day
     * this is to make sure the value is correct when for some reason has skipped more than one cycle payout
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     */
    function _setNextCyclePayoutDay(uint256 cycleNo) internal {
        uint256 maturityDay = s_nextCyclePayoutDay[cycleNo];
        uint256 currentContractDay = s_currentContractDay;
        if (currentContractDay >= maturityDay) {
            s_nextCyclePayoutDay[cycleNo] +=
                cycleNo *
                (((currentContractDay - maturityDay) / cycleNo) + 1);
        }
    }

    /** Views */
    /** @notice Returns current block timestamp
     * @return currentBlockTs current block timestamp
     */
    function getCurrentBlockTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    /** @notice Returns current contract day
     * @return currentContractDay current contract day
     */
    function getCurrentContractDay() public view returns (uint256) {
        return s_currentContractDay;
    }

    /** @notice Returns current mint cost
     * @return currentMintCost current block timestamp
     */
    function getCurrentMintCost() public view returns (uint256) {
        return s_currentMintCost;
    }

    /** @notice Returns current share rate
     * @return currentShareRate current share rate
     */
    function getCurrentShareRate() public view returns (uint256) {
        return s_currentshareRate;
    }

    /** @notice Returns current mintable titan
     * @return currentMintableTitan current mintable titan
     */
    function getCurrentMintableTitan() public view returns (uint256) {
        return s_currentMintableTitan;
    }

    /** @notice Returns current mint power bonus
     * @return currentMintPowerBonus current mint power bonus
     */
    function getCurrentMintPowerBonus() public view returns (uint256) {
        return s_currentMintPowerBonus;
    }

    /** @notice Returns current contract EAA bonus
     * @return currentEAABonus current EAA bonus
     */
    function getCurrentEAABonus() public view returns (uint256) {
        return s_currentEAABonus;
    }

    /** @notice Returns current cycle index for the specified cycle day
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @return currentCycleIndex current cycle index to track the payouts
     */
    function getCurrentCycleIndex(uint256 cycleNo) public view returns (uint256) {
        return s_cyclePayoutIndex[cycleNo];
    }

    /** @notice Returns whether payout is triggered successfully in any cylce day
     * @return isTriggered 0 or 1, 0= No, 1=Yes
     */
    function getGlobalPayoutTriggered() public view returns (PayoutTriggered) {
        return s_isGlobalPayoutTriggered;
    }

    /** @notice Returns the distributed pool reward for the specified cycle day
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @return currentPayoutPool current accumulated payout pool
     */
    function getCyclePayoutPool(uint256 cycleNo) public view returns (uint256) {
        return s_cyclePayouts[cycleNo];
    }

    /** @notice Returns the calculated payout per share and contract day for the specified cycle day and index
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @param index cycle index
     * @return payoutPerShare calculated payout per share
     * @return triggeredDay the day when payout was triggered to perform calculation
     */
    function getPayoutPerShare(
        uint256 cycleNo,
        uint256 index
    ) public view returns (uint256, uint256) {
        return (
            s_cyclePayoutPerShare[cycleNo][index].payoutPerShare,
            s_cyclePayoutPerShare[cycleNo][index].day
        );
    }

    /** @notice Returns user's last claimed shares payout indexes for the specified cycle day
     * @param user user address
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @return cycleIndex cycle index
     * @return sharesIndex shares index
     
     */
    function getUserLastClaimIndex(
        address user,
        uint256 cycleNo
    ) public view returns (uint256 cycleIndex, uint256 sharesIndex) {
        return (
            s_addressCycleToLastClaimIndex[user][cycleNo].cycleIndex,
            s_addressCycleToLastClaimIndex[user][cycleNo].sharesIndex
        );
    }

    /** @notice Returns user's last claimed burn payout index for the specified cycle day
     * @param user user address
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @return burnCycleIndex burn cycle index
     */
    function getUserLastBurnClaimIndex(
        address user,
        uint256 cycleNo
    ) public view returns (uint256 burnCycleIndex) {
        return s_addressCycleToLastClaimIndex[user][cycleNo].burnCycleIndex;
    }

    /** @notice Returns contract deployment block timestamp
     * @return genesisTs deployed timestamp
     */
    function genesisTs() public view returns (uint256) {
        return i_genesisTs;
    }

    /** @notice Returns next payout day for the specified cycle day
     * @param cycleNo cycle day 8, 28, 90, 369, 888
     * @return nextPayoutDay next payout day
     */
    function getNextCyclePayoutDay(uint256 cycleNo) public view returns (uint256) {
        return s_nextCyclePayoutDay[cycleNo];
    }
}
