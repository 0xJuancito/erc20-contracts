// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

interface IFeeManager {
    function processFee() external;
    function processBusdFee(uint256 amount) external;
    function distributeBusdFees() external;
    function distributeETHFees() external;
}