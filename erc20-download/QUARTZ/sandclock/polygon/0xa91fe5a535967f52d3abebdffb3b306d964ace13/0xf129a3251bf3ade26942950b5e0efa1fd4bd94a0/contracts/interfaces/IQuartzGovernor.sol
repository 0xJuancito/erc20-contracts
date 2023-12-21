// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IQuartzGovernor {
    function withdrawRequiredVotes(
        address from,
        uint256 amount,
        bool force
    ) external;

    function getTotalUserVotes(address _voter) external view returns (uint256);
}
