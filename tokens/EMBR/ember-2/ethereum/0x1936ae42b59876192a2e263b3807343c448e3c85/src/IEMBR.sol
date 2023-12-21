// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEMBRToken {
    function mint_allowance(address addy) external returns (uint);
    function mintWithAllowance(uint amount, address receiver) external;
}
