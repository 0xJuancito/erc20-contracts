//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

interface IIncentiveReceiver {
    function deposit(address _token, uint256 _amount) external;

    function addDepositor(address _depositor) external;
}
