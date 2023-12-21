// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


interface IChecker {
    function checkSniper(address from, address to, uint256 value) external returns (bool);
}
