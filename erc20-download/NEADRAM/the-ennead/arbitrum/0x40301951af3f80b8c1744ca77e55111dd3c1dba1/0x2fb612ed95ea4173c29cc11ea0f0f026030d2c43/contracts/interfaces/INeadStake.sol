// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface INeadStake {
    function notifyRewardAmount(address token, uint amount) external;
}
