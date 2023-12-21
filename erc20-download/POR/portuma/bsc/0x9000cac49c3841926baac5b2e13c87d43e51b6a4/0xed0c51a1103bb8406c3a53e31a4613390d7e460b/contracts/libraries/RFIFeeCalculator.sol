// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RFIFeeCalculator {
    uint256 private constant HOUR = 60 * 60;

    struct feeData {
        uint256 burnFee;
        uint256 holderFee;
        uint256 marketingFee; 
    }

    struct transactionFee {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 rMarketing;
        uint256 rBurn;

        uint256 tAmount;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tMarketing;
        uint256 tBurn;

        uint256 currentRate;
    }

    struct taxTiers {
        uint256[] time;
        mapping(uint256 => feeData) tax;
    }

    function calculateFees(
        uint256 amount,
        uint256 rate,
        feeData memory fd,
        bool isSell,
        taxTiers storage tt,
        uint256 tss
    ) internal view returns (transactionFee memory) {
        transactionFee memory tf;
        tf.currentRate = rate;

        tf.tAmount    = amount;
        tf.tBurn      = calculateFee(amount, isSell ? getCurrentBurnFeeOnSale(tss, tt, fd) : fd.burnFee);
        tf.tFee       = calculateFee(amount, isSell ? getCurrentHolderFeeOnSale(tss, tt, fd) : fd.holderFee);
        tf.tMarketing = calculateFee(amount, isSell ? getCurrentMarketingFeeOnSale(tss, tt, fd) : fd.marketingFee);
        
        tf.tTransferAmount = amount - tf.tFee - tf.tMarketing - tf.tBurn;
        
        tf.rAmount     = tf.tAmount * tf.currentRate;
        tf.rBurn       = tf.tBurn * tf.currentRate;
        tf.rFee        = tf.tFee * tf.currentRate;
        tf.rMarketing  = tf.tMarketing * tf.currentRate;

        tf.rTransferAmount = tf.rAmount - tf.rFee - tf.rMarketing - tf.rBurn;

        return tf;
    }

    function calculateFee(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return (amount * fee) / 10**4;
    }

    function getCurrentBurnFeeOnSale(
        uint256 time_since_start,
        taxTiers storage tt,
        feeData memory fd
    ) internal view returns (uint256 fee) {
        fee = fd.burnFee;
        if (time_since_start < tt.time[0] * HOUR) {
            fee = tt.tax[0].burnFee;
        } else if (time_since_start < tt.time[1] * HOUR) {
            fee = tt.tax[1].burnFee;
        } else if (time_since_start < tt.time[2] * HOUR) {
            fee = tt.tax[2].burnFee;
        } else if (time_since_start < tt.time[3] * HOUR) {
            fee = tt.tax[3].burnFee;
        }
    }

    function getCurrentHolderFeeOnSale(
        uint256 time_since_start,
        taxTiers storage tt,
        feeData memory fd
    ) internal view returns (uint256 fee) {
        fee = fd.holderFee;
        if (time_since_start < tt.time[0] * HOUR) {
            fee = tt.tax[0].holderFee;
        } else if (time_since_start < tt.time[1] * HOUR) {
            fee = tt.tax[1].holderFee;
        } else if (time_since_start < tt.time[2] * HOUR) {
            fee = tt.tax[2].holderFee;
        } else if (time_since_start < tt.time[3] * HOUR) {
            fee = tt.tax[3].holderFee;
        }
    }

    function getCurrentMarketingFeeOnSale(
        uint256 time_since_start,
        taxTiers storage tt,
        feeData memory fd
    ) internal view returns (uint256 fee) {
        fee = fd.marketingFee;
        if (time_since_start < tt.time[0] * HOUR) {
            fee = tt.tax[0].marketingFee;
        } else if (time_since_start < tt.time[1] * HOUR) {
            fee = tt.tax[1].marketingFee;
        } else if (time_since_start < tt.time[2] * HOUR) {
            fee = tt.tax[2].marketingFee;
        } else if (time_since_start < tt.time[3] * HOUR) {
            fee = tt.tax[3].marketingFee;
        }
    }
}