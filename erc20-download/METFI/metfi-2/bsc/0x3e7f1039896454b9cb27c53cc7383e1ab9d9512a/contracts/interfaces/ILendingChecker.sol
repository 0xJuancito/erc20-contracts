// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending checker contract
// @author MetFi
// @notice This contract is responsible for checking loans and lending configuration values
interface ILendingChecker is ILendingStructs {
    function checkLendingConfig(
        LendingConfiguration calldata config
    ) external pure;

    function checkLoan(
        CreateLoanRequest calldata request,
        address msgSender
    ) external view;
}
