// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;


import "./ILocker.sol";

interface ILockerUser {
    function locker() external view returns (ILocker);
}