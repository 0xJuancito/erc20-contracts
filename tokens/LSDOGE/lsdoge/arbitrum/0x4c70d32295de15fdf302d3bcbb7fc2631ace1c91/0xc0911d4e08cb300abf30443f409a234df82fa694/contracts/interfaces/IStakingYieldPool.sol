// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.19;

interface IStakingYieldPool {
    function notifyRewardAmount(uint256 reward) external;
}