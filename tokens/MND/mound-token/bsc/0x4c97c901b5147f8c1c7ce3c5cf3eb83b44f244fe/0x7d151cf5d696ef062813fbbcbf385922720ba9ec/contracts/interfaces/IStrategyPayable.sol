// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./IStrategy.sol";

interface IStrategyPayable is IStrategy {
    function deposit(uint amount) external payable;
}