pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IBorrowable.sol";

library BorrowableHelpers {
    using SafeMath for uint256;

    uint256 private constant RATE_SCALE = 1e18;

    function borrowableValueOf(IBorrowable borrowable, uint256 underlyingAmount) internal returns (uint256) {
        if (underlyingAmount == 0) {
            return 0;
        }
        uint256 exchangeRate = borrowable.exchangeRate();
        return underlyingAmount.mul(1e18).div(exchangeRate);
    }

    function underlyingValueOf(IBorrowable borrowable, uint256 borrowableAmount) internal returns (uint256) {
        if (borrowableAmount == 0) {
            return 0;
        }
        uint256 exchangeRate = borrowable.exchangeRate();
        return borrowableAmount.mul(exchangeRate).div(1e18);
    }

    function underlyingBalanceOf(IBorrowable borrowable, address account) internal returns (uint256) {
        return underlyingValueOf(borrowable, borrowable.balanceOf(account));
    }

    function myUnderlyingBalance(IBorrowable borrowable) internal returns (uint256) {
        return underlyingValueOf(borrowable, borrowable.balanceOf(address(this)));
    }

    function getNextBorrowRate(
        IBorrowable borrowable,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) internal returns (uint256 borrowRate_, uint256 utilizationRate_) {
        require(depositAmount == 0 || withdrawAmount == 0, "BH: INVLD_DELTA");
        borrowable.accrueInterest();
        {
            uint256 totalBorrows = borrowable.totalBorrows();
            uint256 nextBalance = borrowable.totalBalance().add(totalBorrows);
            if (depositAmount > 0) {
                nextBalance = nextBalance.add(depositAmount);
            }
            if (withdrawAmount > 0) {
                nextBalance = nextBalance.sub(withdrawAmount);
            }
            utilizationRate_ = (nextBalance == 0) ? 0 : totalBorrows.mul(RATE_SCALE).div(nextBalance);
        }

        uint256 kinkUtilizationRate = borrowable.kinkUtilizationRate(); // gas savings

        if (utilizationRate_ <= kinkUtilizationRate) {
            borrowRate_ = borrowable.kinkBorrowRate().mul(utilizationRate_).div(kinkUtilizationRate);
        } else {
            borrowRate_ = borrowable.KINK_MULTIPLIER().sub(1);

            {
                // utilizationRate_ is strictly less than kinkUtilizationRate
                uint256 overUtilization = utilizationRate_.sub(kinkUtilizationRate).mul(RATE_SCALE).div(
                    RATE_SCALE.sub(kinkUtilizationRate)
                );
                borrowRate_ = borrowRate_.mul(overUtilization);
            }

            borrowRate_ = borrowRate_.add(RATE_SCALE).mul(borrowable.kinkBorrowRate()).div(RATE_SCALE);
        }

        borrowRate_ = uint48(borrowRate_);
    }

    function getNextSupplyRate(
        IBorrowable borrowable,
        uint256 depositAmount,
        uint256 withdrawAmount
    )
        internal
        returns (
            uint256 supplyRate_,
            uint256 borrowRate_,
            uint256 utilizationRate_
        )
    {
        (borrowRate_, utilizationRate_) = getNextBorrowRate(borrowable, depositAmount, withdrawAmount);

        supplyRate_ = borrowRate_
            .mul(utilizationRate_)
            .div(RATE_SCALE)
            .mul(RATE_SCALE.sub(borrowable.reserveFactor()))
            .div(RATE_SCALE);
    }

    function getCurrentBorrowRate(IBorrowable borrowable)
        internal
        returns (uint256 borrowRate_, uint256 utilizationRate_)
    {
        return getNextBorrowRate(borrowable, 0, 0);
    }

    function getCurrentSupplyRate(IBorrowable borrowable)
        internal
        returns (
            uint256 supplyRate_,
            uint256 borrowRate_,
            uint256 utilizationRate_
        )
    {
        return getNextSupplyRate(borrowable, 0, 0);
    }
}
