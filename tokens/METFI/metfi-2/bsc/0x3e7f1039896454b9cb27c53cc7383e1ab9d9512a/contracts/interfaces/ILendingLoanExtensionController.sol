// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "./ILendingStructs.sol";

// @title MetFi Lending Extension contract
// @author MetFi
// @notice This contract is responsible for EIP712 signatures for loan extensions
interface ILendingLoanExtensionController is ILendingStructs {
    function checkLenderSignatures(
        ExtendLoanRequest calldata request,
        LenderInfo[] calldata lenders
    ) external view;
}
