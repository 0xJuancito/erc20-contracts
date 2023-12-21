// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
 * ChildToken interface for PoS bridge
 */
interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;

    function withdraw(uint256 amount) external;
}
