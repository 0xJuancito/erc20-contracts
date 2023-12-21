// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

import './Declaration.sol';

abstract contract Timing is Declaration {

    /**
    * @notice external view function to get current FeyDay, unless called at LAUNCH_TIME, in which case it will return 0 to save gas
    * @dev called by _currentFeyDay
    * @return current FeyDay
    */
    function currentFeyDay()
        public
        view
        returns (uint64)
    {
        return getNow() >= LAUNCH_TIME
            ? _currentFeyDay()
            : 0;
    }

    /**
    * @notice internal view function to calculate current FeyDay by using _feyDayFromStamp()
    * @dev called by snapshotTrigger(), manualDailySnapshot(), + getStakeInterest()
    * @return current FeyDay
    */
    function _currentFeyDay()
        internal
        view
        returns (uint64)
    {
        return _feyDayFromStamp(getNow());
    }

    /**
    * @notice calculates difference between passed timestamp + original LAUNCH_TIME, set when contract was deployed
    * @dev called by _currentFeyDay
    * @param _timestamp -- timestamp to use for difference
    * @return number of days between timestamp param + LAUNCH_TIME 
    */
    function _feyDayFromStamp(
        uint256 _timestamp
    )
        internal
        view
        returns (uint64)
    {
        return uint64((_timestamp - LAUNCH_TIME) / SECONDS_IN_DAY);
    }
    
    /**
    * @dev called by getStakeAge(), getStakePenalty, closeStake(), openStake(), + _currentFeyDay
    * @return current block.timestamp
    */
    function getNow()
        public
        view
        returns (uint256)
    {
        return block.timestamp;
    }

}