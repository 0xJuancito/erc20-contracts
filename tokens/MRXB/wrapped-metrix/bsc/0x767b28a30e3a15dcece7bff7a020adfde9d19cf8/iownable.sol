// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

interface IOwnable
    {
    function getOwner() external view returns (address);
    modifier isOwner() virtual;
    }
