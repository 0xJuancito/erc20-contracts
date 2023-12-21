// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}