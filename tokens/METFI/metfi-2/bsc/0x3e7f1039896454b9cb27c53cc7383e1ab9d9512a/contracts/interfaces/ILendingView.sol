// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending View contract
// @author MetFi
// @notice This contract is a central point for getting information about loans
interface ILendingView is ILendingStructs {
    function getLoanInfo(
        uint256 loanId
    ) external view returns (LoanInfo memory);

    function getLoansByBorrower(
        address borrower
    ) external view returns (LoanInfo[] memory);

    function getLoansByLender(
        address lender
    ) external view returns (LoanInfo[] memory);

    function getLoanCollateralization(
        uint256 loanId
    ) external view returns (uint256);

    function getActiveLoans() external view returns (LoanInfo[] memory);

    function getLoanExtensionRequest(
        uint256 loanId
    ) external view returns (ExtendLoanRequest memory);

    function getLoansForLiquidationByCollateralRatio()
        external
        view
        returns (uint256[] memory);

    function getLoansForInvalidation() external view returns (uint256[] memory);

    function canLoanBeLiquidatedByCollateralRatio(
        uint256 loanId
    ) external view returns (bool);

    function canLoanBeLiquidatedByDeadline(
        uint256 loanId
    ) external view returns (bool);

    function getMaxLoanValueForToken(
        uint256 tokenId
    ) external view returns (uint256);

    function getMaxLoanValueForLoan(
        uint256 loanId
    ) external view returns (uint256);

    function getMaxLoanValueForMFI(
        uint256 mfiAmount
    ) external view returns (uint256);

    function getNewLeverageIndexForLoanAndCollateral(
        uint256 loanId,
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function getBUSDValueOf(
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function getMFIValueOf(
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function getRemainingMaxLoanAmount() external view returns (uint256);
}
