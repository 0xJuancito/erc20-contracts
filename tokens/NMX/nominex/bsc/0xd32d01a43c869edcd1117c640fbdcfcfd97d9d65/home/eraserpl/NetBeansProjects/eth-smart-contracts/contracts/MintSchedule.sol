// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./Lib.sol";
import "./RecoverableByOwner.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

contract MintSchedule is RecoverableByOwner {
    /**
     @dev structure to describe the mint schedule. After each week MintScheduleState.nextTickSupply decreases.
     When the schedule completes weekCount weeks in current item it goes to the next item in the items.
     @param weekCount duration of the item in weeks
     @param weekCompletenessMultiplier a number nextTickSupply is multiplied by after each week in the item
     @param poolShares shares of the mint pool in the item
     */
    struct ScheduleItem {
        uint16 weekCount;
        int128 weekCompletenessMultiplier;
        int128[] poolShares;
    }
    uint40 constant WEEK_DURATION = 7 days;

    using ABDKMath64x64 for int128;
    ScheduleItem[] public items; /// @dev array of shcedule describing items

    constructor() {
        // 0.0, 0.625, 0.375
        int128[3] memory shares_01_28 =
            [
                0,
                ABDKMath64x64.divu(625, 1000),
                ABDKMath64x64.divu(375, 1000)
            ];

        // 0.0, 0.5625, 0.4375
        int128[3] memory shares_29_56 =
            [
                0,
                ABDKMath64x64.divu(5625, 10000),
                ABDKMath64x64.divu(4375, 10000)
            ];

        // 0.0, 0.5, 0.5
        int128[3] memory shares_57_xx =
            [
                0,
                ABDKMath64x64.divu(5, 10),
                ABDKMath64x64.divu(5, 10)
            ];

        /* period 1-7 days | duration 7 days | summary 1 week */
        ScheduleItem storage item = items.push();
        item.weekCount = 1;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(75, 100);
        item.poolShares = shares_01_28;

        /* period 8-14 days | duration 7 days | summary 2 weeks */
        item = items.push();
        item.weekCount = 1;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(35, 100);
        item.poolShares = shares_01_28;

        /* period 15-28 days | 2 weeks | summary 4 weeks */
        item = items.push();
        item.weekCount = 2;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(104, 100);
        item.poolShares = shares_01_28;

        /* period 29-56 days | 4 weeks | summary 8 weeks */
        item = items.push();
        item.weekCount = 4;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(104, 100);
        item.poolShares = shares_29_56;

        /* period 57-105 days | 7 weeks | summary 15 weeks */
        item = items.push();
        item.weekCount = 7;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(104, 100);
        item.poolShares = shares_57_xx;

        /* period 106-196 days | duration 3 months | summary 28 weeks */
        item = items.push();
        item.weekCount = 13;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(102, 100);
        item.poolShares = shares_57_xx;

        /* period 197-287 days | duration 3 months | summary 41 weeks */
        item = items.push();
        item.weekCount = 13;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(101, 100);
        item.poolShares = shares_57_xx;

        /* period 288-378 days | duration 3 months | summary 54 weeks */
        item = items.push();
        item.weekCount = 13;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(1, 1);
        item.poolShares = shares_57_xx;

        /* period 379-560 days | duration 6 months | summary 80 weeks */
        item = items.push();
        item.weekCount = 26;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9995, 10000);
        item.poolShares = shares_57_xx;

        /* period 561-742 days | duration 6 months | summary 106 weeks */
        item = items.push();
        item.weekCount = 26;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(999, 1000);
        item.poolShares = shares_57_xx;

        /* period 743-924 days | duration 6 months | summary 132 weeks */
        item = items.push();
        item.weekCount = 26;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9985, 10000);
        item.poolShares = shares_57_xx;

        /* period 925-1106 days | duration 6 months | summary 158 weeks */
        item = items.push();
        item.weekCount = 26;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(998, 1000);
        item.poolShares = shares_57_xx;

        /* period 1107-1470 days | duration 1 year | summary 210 weeks */
        item = items.push();
        item.weekCount = 52;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9975, 10000);
        item.poolShares = shares_57_xx;

        /* period 1471-1834 days | duration 1 year | summary 262 weeks */
        item = items.push();
        item.weekCount = 52;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(997, 1000);
        item.poolShares = shares_57_xx;

        /* period 1835-2198 days | duration 1 year | summary 314 weeks */
        item = items.push();
        item.weekCount = 52;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9965, 10000);
        item.poolShares = shares_57_xx;

        /* period 2199-2562 days | duration 1 year | summary 366 weeks */
        item = items.push();
        item.weekCount = 52;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(996, 1000);
        item.poolShares = shares_57_xx;

        /* period 2563-2926 days | duration 1 year | summary 418 weeks */
        item = items.push();
        item.weekCount = 52;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(997, 1000);
        item.poolShares = shares_57_xx;

        /* period 2927-3654 days | duration 2 year | summary 522 weeks */
        item = items.push();
        item.weekCount = 104;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(998, 1000);
        item.poolShares = shares_57_xx;

        /* period 3655-5110 days | duration 4 years | summary 730 weeks */
        item = items.push();
        item.weekCount = 208;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(999, 1000);
        item.poolShares = shares_57_xx;

        /* period 5111-8022 days | duration 8 years | summary 1146 weeks */
        item = items.push();
        item.weekCount = 416;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9995, 10000);
        item.poolShares = shares_57_xx;

        /* period 8023-22582 days | duration 40 years | summary 3226 weeks */
        item = items.push();
        item.weekCount = 2080;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(9999, 10000);
        item.poolShares = shares_57_xx;

        /* period 22583-26096 days | duration 10 years (without 18 weeks) | summary 3728 weeks */
        item = items.push();
        item.weekCount = 502;
        item.weekCompletenessMultiplier = ABDKMath64x64.divu(99995, 100000);
        item.poolShares = shares_57_xx;
    }

    /**
     @dev calculates changes in scheduleState based on the time passed from last update and returns updated state and amount of Nmx to be minted
     */
    function makeProgress(
        MintScheduleState memory scheduleState,
        uint40 time,
        MintPool pool
    ) external view returns (uint256 nmxSupply, MintScheduleState memory) {
        if (time <= scheduleState.time) return (0, scheduleState);
        while (
            time > scheduleState.time && scheduleState.itemIndex < items.length
        ) {
            ScheduleItem storage item = items[scheduleState.itemIndex];
            uint40 boundary =
                min(time, scheduleState.weekStartTime + WEEK_DURATION);
            uint256 secondsFromLastUpdate = boundary - scheduleState.time;
            nmxSupply +=
                secondsFromLastUpdate *
                item.poolShares[uint256(pool)].mulu(
                    uint256(scheduleState.nextTickSupply)
                );
            persistStateChange(scheduleState, item, boundary);
        }
        return (nmxSupply, scheduleState);
    }

    function persistStateChange(
        MintScheduleState memory state,
        ScheduleItem memory item,
        uint40 time
    ) private pure {
        state.time = time;
        if (time == state.weekStartTime + WEEK_DURATION) {
            state.nextTickSupply = uint128(
                item.weekCompletenessMultiplier.mulu(
                    uint256(state.nextTickSupply)
                )
            );
            state.weekIndex++;
            state.weekStartTime = time;
            if (state.weekIndex == item.weekCount) {
                state.weekIndex = 0;
                state.itemIndex++;
            }
        }
    }

    function min(uint40 a, uint40 b) private pure returns (uint40) {
        if (a < b) return a;
        return b;
    }
}
