// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IStrategy {
    function deposit(uint256 amount) external;

    function reinvest() external;

    function withdraw(uint256 amount) external;
}
