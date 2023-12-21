// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}
