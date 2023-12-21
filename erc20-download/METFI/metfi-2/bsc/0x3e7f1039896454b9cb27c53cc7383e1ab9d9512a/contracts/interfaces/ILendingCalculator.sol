// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending Calculator contract
// @author MetFi
// @notice This contract is responsible for calculating loan values
interface ILendingCalculator is ILendingStructs {
    function calculateLoanPercentageOfCollateralValue(
        uint256 tokenId,
        uint256 outstandingAmountBUSD,
        address[] calldata additionalCollateralAddresses,
        uint256[] calldata additionalCollateralAmounts
    ) external view returns (uint256);

    function calculateLoanPercentageOfStakedMFIValue(
        uint256 outstandingLoanAmount,
        uint256 tokenId
    ) external view returns (uint256);

    function calculateInterest(
        uint256 amount,
        uint256 apy,
        uint256 duration
    ) external pure returns (uint256);

    function checkLoanForInvalidation(
        LoanInfo calldata loanInfo
    ) external view returns (bool);

    function checkLoanForLiquidationByCollateral(
        LoanInfo calldata loanInfo
    ) external view returns (bool);

    function checkLoanForLiquidationByDeadline(
        LoanInfo calldata loanInfo
    ) external view returns (bool);

    function calculateLiquidationData(
        LoanInfo calldata loanInfo
    ) external view returns (LiquidationData memory, bool);

    function calculateCurrentTotalNFTRewards(
        uint256 tokenId
    ) external view returns (uint256);

    function calculateMaxLoanAmountForMFI(
        uint256 mfiAmount
    ) external view returns (uint256);

    function calculateMaxLoanAmountForToken(
        uint256 tokenId
    ) external view returns (uint256);

    function calculateMaxLoanAmountForLoan(
        uint256 loanId
    ) external view returns (uint256);

    function calculateBUSDValueOf(
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function calculateMFIValueOf(
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function calculateNewLeverageIndexForLoanAndCollateral(
        LoanInfo calldata loan,
        address currency,
        uint256 amount
    ) external view returns (uint256);

    function calculateMaxLoanAmountForMFIAndCollateral(
        uint256 mfiAmount,
        address[] calldata additionalCollateralAddresses,
        uint256[] calldata additionalCollateralAmounts,
        address newCollateralAddress,
        uint256 newCollateralAmount
    ) external view returns (uint256);
}
