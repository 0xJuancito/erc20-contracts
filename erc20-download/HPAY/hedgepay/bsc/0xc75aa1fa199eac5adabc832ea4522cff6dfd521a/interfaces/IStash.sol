// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

/**
   Stash rewards until they are ready to be claimed
*/
interface IRewardStash {
    // Add amount to stash
    function stash(uint256 value) external ;

    // Remote amount from stash
    function unstash(uint256 value) external;

    // Returns the current value of the stash
    function stashValue() external view returns(uint256);
}