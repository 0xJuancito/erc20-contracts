// SPDX-License-Identifier: MIT
/*
    Created by DeNet
    
    Interface for DeNetFileToken 
*/

pragma solidity ^0.8.0;

interface IDeNetFileToken {
    event UpdateTreasury(
        address indexed _to,
        uint256 _year
    );

    event NewYear (
        uint indexed _year,
        uint _yearTimeStamp
    );
}