// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface IFeeDiscountOracle {
    function buyFeeDiscountFor(address account, uint256 totalFeeAmount)
        external
        view
        returns (uint256 discountAmount);

    function sellFeeDiscountFor(address account, uint256 totalFeeAmount)
        external
        view
        returns (uint256 discountAmount);
}
