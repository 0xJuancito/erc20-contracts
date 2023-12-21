// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (finance/VestingWallet.sol)
pragma solidity ^0.8.9;

import "./VestingWallet.sol";


contract MonthlyVestingWallet is VestingWallet {
    uint64[] public _schedule;
    uint64 public immutable _scheduleInterval;
    uint64 public immutable _initialMintingPercent;
    address public immutable _beneficiary;
    uint64 private _start;

    uint64 constant internal SECONDS_PER_MONTH = 2628288;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 initialMintingPercent,
        uint64[] memory schedule,
        uint64 scheduleInterval
    ) VestingWallet(beneficiaryAddress, startTimestamp, uint64(schedule.length) * scheduleInterval){
        require(beneficiaryAddress != address(0), "MonthlyVestingWallet: beneficiary is zero address");
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _initialMintingPercent = initialMintingPercent;
        _schedule = schedule;
        _scheduleInterval = scheduleInterval;
    }


    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual override returns (uint256) {
        return totalAllocation * monthlyVestingPercent(timestamp) / 10000;
    }

    /**
     * @dev Calculates the percentage of tokens that has already vested as a function of time.
     */
    function monthlyVestingPercent(uint64 timestamp) public view returns (uint64) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return 10000;
        }

        uint64 secondsAfterStart = timestamp - uint64(start());
        uint64 step = secondsAfterStart / _scheduleInterval;
        return getStepPercent(step+1);
    }

    /**
     * @dev Calculates the percentage of tokens in specific step of vesting
     */
    function getStepPercent(uint step) public view returns (uint64) {
        uint64 acumulatedPercent = _initialMintingPercent;
        for (uint i = 0; i < step; i++) {
            acumulatedPercent += _schedule[i];
        }
        return acumulatedPercent * 100;
    }

}