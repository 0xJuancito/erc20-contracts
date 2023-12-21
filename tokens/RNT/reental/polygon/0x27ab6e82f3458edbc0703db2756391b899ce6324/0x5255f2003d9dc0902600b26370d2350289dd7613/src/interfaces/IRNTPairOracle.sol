// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IRNTPairOracle {
    function checkTransfer(address from, address to, uint256 value) external view returns (bool);
    function isPair(address pair) external view returns (bool);
    function isManager(address manager) external view returns (bool);
}
