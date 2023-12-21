// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending contract
// @author MetFi
// @notice This contract is responsible for managing loans
interface ILending is ILendingStructs {
    //----------------- Getters -------------------------------------------------

    function getLendingConfiguration()
        external
        view
        returns (LendingConfiguration memory);

    function getLoanById(
        uint256 loanId
    ) external view returns (LoanInfo memory);

    //----------------- User functions -------------------------------------------

    function createLoan(CreateLoanRequest calldata request) external;

    function cancelLoan(uint256 loanId) external;

    function fundLoan(FundLoanRequest calldata request) external;

    function repayLoan(RepayLoanRequest memory request) external;

    function requestLoanExtension(
        ExtendLoanRequest calldata request
    ) external payable;

    function removeFunding(uint256 loanId) external;

    function addCollateral(AddCollateralRequest memory request) external;

    function liquidateLoanByDeadline(uint256 loanId) external;

    //----------------- System functions ------------------------------------------

    function extendLoan(ExtendLoanRequest calldata request) external;

    function liquidateLoans(uint256[] calldata loanId) external;

    function invalidateLoans(uint256[] calldata loanId) external;

    function migrateToNewLendingContract(
        uint256 maxLoansToProcess,
        address recipient
    ) external returns (uint256[] memory);

    //----------------- Manager functions ------------------------------------------
    function setLendingConfiguration(
        LendingConfiguration calldata newConfiguration
    ) external;
}
