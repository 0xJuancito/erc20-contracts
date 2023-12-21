// SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.7;

interface IDividendDistributor {
    function deposit(uint256 amount) external;

    function claimStaking() external;
}
