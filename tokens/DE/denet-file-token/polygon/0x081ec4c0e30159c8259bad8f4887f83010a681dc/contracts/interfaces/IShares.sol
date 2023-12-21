// SPDX-License-Identifier: MIT
/*
    Created by DeNet
    
    Interface for Shares 
*/

pragma solidity ^0.8.0;

interface IShares {
    event NewShares(
        address indexed _to,
        uint256 _value
    );

    event DropShares(
        address indexed _to,
        uint256 _value
    );
}