// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

import "./Helper.sol";

abstract contract Snapshot is Helper {

    using SafeMath for uint;


    /**
    * @notice modifier to capture snapshots when a stake is opened
    * @dev used in OpenStake() in FeyToken 
    */
    modifier snapshotTriggerOnOpen() 
    {
        _;
        _dailySnapshotPoint(
            _currentFeyDay()
        );
    }
    
    
    /**
    * @notice modifier to capture snapshots when a stake is closed
    * @dev used in CloseStake() in FeyToken 
    */
    modifier snapshotTriggerOnClose() 
    {
        _dailySnapshotPoint(
            _currentFeyDay()
        );
        _;
    }

    /**
    * @notice Manually capture snapshot
    */
    function manualDailySnapshot() 
        external
    {
        _dailySnapshotPoint(
            _currentFeyDay()
        );
    }

    /**
    * @notice takes in todays feyday + updates all missing snapshot days with todays data
    * @param _updateDay -- current FeyDay as outputted from timing's _currentFeyDay() function
    * Emits SnapshotCaptured event
    */
    function _dailySnapshotPoint(
        uint64 _updateDay
    )
        private
    {
        for (uint256 _day = globals.currentFeyDay; _day < _updateDay; _day++) {

            SnapShot memory s = snapshots[_day];

            s.totalSupply = totalSupply;
            s.totalStakedAmount = globals.totalStakedAmount;
            

            snapshots[_day] = s;

            globals.currentFeyDay++;
        }

        emit SnapshotCaptured(
            totalSupply,
            globals.totalStakedAmount,
            _updateDay
        );
    }
}