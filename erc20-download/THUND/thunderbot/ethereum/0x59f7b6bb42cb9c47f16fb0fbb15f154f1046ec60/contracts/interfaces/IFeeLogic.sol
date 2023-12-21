// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.8;

interface IFeeLogic {
    function shouldApplyFees(address from, address to) external view returns (bool);
}
