// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Vesting library
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev  This library defines a struct and provides utility functions for 
 * tracking an amount that vests over time.
 * @dev Unvested amounts may be spent to attend events, purchase NFTs, or 
 * participate in other experiences or utilities offered by ViciNFT.
 */

struct VestingSchedule {
    // the initial amount of the airdrop
    uint256 startingAmount;
    // total funds spent purchasing from ViciNFT
    uint256 amountSpent;
    // vesting start time
    uint64 start;
    // length of the vesting period
    uint64 duration;
}

library Vesting {
    /**
     * @dev Returns the portion of the original amount that remains unvested, 
     * less any amount that has been spent through ViciNFT.
     */
    function getLockedAmount(
        VestingSchedule storage schedule,
        uint256 timestamp
    ) internal view returns (uint256) {
        // start == 0 means the thing is uninitialized
        // current time after start+duration means fully vested
        if (
            schedule.start == 0 ||
            timestamp >= schedule.start + schedule.duration
        ) {
            return 0;
        }

        // current time before start means not vested
        if (timestamp <= schedule.start) {
            return schedule.startingAmount - schedule.amountSpent;
        }

        // total amount * percent of vesting period past
        uint256 preSpendingLockAmount = schedule.startingAmount -
            (schedule.startingAmount * (timestamp - schedule.start)) /
            schedule.duration;

        // we've spent all the remaining locked tokens
        if (schedule.amountSpent > preSpendingLockAmount) {
            return 0;
        }

        // remaining locked tokens less tokens spent through ViciNFT
        return preSpendingLockAmount - schedule.amountSpent;
    }
}
