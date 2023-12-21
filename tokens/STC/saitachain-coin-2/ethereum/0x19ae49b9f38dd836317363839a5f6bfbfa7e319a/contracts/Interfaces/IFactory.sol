// SPDX-License-Identifier: NOLICENSE
pragma solidity ^0.8.10;

interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
}