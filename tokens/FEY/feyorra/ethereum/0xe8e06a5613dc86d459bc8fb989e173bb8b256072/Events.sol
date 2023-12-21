// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

abstract contract Events  {

    event StakeStart(
        uint256 indexed _stakingId,
        address _address,
        uint256 _amount
    );

    event StakeEnd(
        uint256 indexed _stakingId,
        address _address,
        uint256 _amount
    );

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    event ClosedGhostStake(
        uint256 daysOld,
        uint256 secondsOld,
        uint256 stakeId
    );

    event SnapshotCaptured(
        uint256 _totalSupply,
        uint256 _totalStakedAmount,
        uint64 _snapshotDay
    );
}