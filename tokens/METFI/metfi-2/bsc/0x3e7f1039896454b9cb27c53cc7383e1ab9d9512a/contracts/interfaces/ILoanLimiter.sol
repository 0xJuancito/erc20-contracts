// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending Limiter contract
// @author MetFi
// @notice This contract is responsible for limiting loans
interface ILoanLimiter is ILendingStructs{
    function canLoanBeCreated(CreateLoanRequest memory loanRequest) external view returns (bool);

    function onLoanCreated(LoanInfo memory loanInfo, CreateLoanRequest memory loanRequest) external;

    function onLoanFunded(LoanInfo memory loanInfo, FundLoanRequest memory fundLoanRequest) external;

    function onLoanRepaid(LoanInfo memory loanInfo, RepayLoanRequest memory repayLoanRequest) external;

    function onLoanExtended(LoanInfo memory loanInfo, ExtendLoanRequest memory extendLoanRequest) external;

    function onLoanLiquidated(LoanInfo memory loanInfo) external;

    function onLoanInvalidated(LoanInfo memory loanInfo) external;


}