// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

uint constant DENOMINATOR = 1e18;

struct MpAsset {
    uint quantity;
    uint price;
    uint collectedFees;
    uint collectedCashbacks;
    uint share;
    uint decimals;
}

struct MpContext {
    uint usdCap;
    uint totalTargetShares;
    uint halfDeviationFee;
    uint deviationLimit;
    uint operationBaseFee;
    uint userCashbackBalance;
    uint depegBaseFee;
}

using {MpCommonMath.evalMint, MpCommonMath.evalBurn} for MpContext global;

using {MpCommonMath.to18, MpCommonMath.toNative} for MpAsset global;

library MpCommonMath {
    function abs(uint a, uint b) internal pure returns (uint c) {
        c = a > b ? a - b : b - a;
    }

    function toNative(MpAsset memory asset, uint quantity) internal pure returns (uint scaled) {
        if (asset.decimals > 18) {
            scaled = quantity * (10 ** (asset.decimals - 18));
        } else {
            scaled = quantity / (10 ** (18 - asset.decimals));
        }
    }

    function to18(MpAsset memory asset, uint quantity) internal pure returns (uint scaled) {
        if (asset.decimals > 18) {
            scaled = quantity / (10 ** (asset.decimals - 18));
        } else {
            scaled = quantity * (10 ** (18 - asset.decimals));
        }
    }

    function evalMint(MpContext memory context, MpAsset memory asset, uint utilisableQuantity)
        internal
        pure
        returns (uint suppliedQuantity)
    {
        if (context.usdCap == 0) {
            context.usdCap = (utilisableQuantity * asset.price) / DENOMINATOR;
            asset.quantity += utilisableQuantity;
            return utilisableQuantity;
        }

        uint shareOld = (asset.quantity * asset.price) / context.usdCap;
        uint shareNew = ((asset.quantity + utilisableQuantity) * asset.price)
            / (context.usdCap + (utilisableQuantity * asset.price) / DENOMINATOR);
        uint targetShare = (asset.share * DENOMINATOR) / context.totalTargetShares;
        uint deviationNew = abs(shareNew, targetShare);
        uint deviationOld = abs(shareOld, targetShare);

        if (deviationNew <= deviationOld) {
            if (deviationOld != 0) {
                uint cashback = (asset.collectedCashbacks * (deviationOld - deviationNew)) / deviationOld;
                asset.collectedCashbacks -= cashback;
                context.userCashbackBalance += cashback;
            }
            suppliedQuantity = (utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR;
        } else {
            require(deviationNew < context.deviationLimit, "MULTIPOOL: DO");
            uint depegFee = (context.halfDeviationFee * deviationNew * utilisableQuantity) / context.deviationLimit
                / (context.deviationLimit - deviationNew);
            uint deviationBaseFee = (context.depegBaseFee * depegFee) / DENOMINATOR;
            asset.collectedCashbacks += depegFee - deviationBaseFee;
            asset.collectedFees += deviationBaseFee;
            suppliedQuantity = ((utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR + depegFee);
        }

        require(suppliedQuantity != 0, "MULTIPOOL: ZS");

        context.usdCap -= (asset.quantity * asset.price) / DENOMINATOR;
        asset.quantity += utilisableQuantity;
        context.usdCap += (asset.quantity * asset.price) / DENOMINATOR;
        asset.collectedFees += (utilisableQuantity * context.operationBaseFee) / DENOMINATOR;
    }

    function evalBurn(MpContext memory context, MpAsset memory asset, uint suppliedQuantity)
        internal
        pure
        returns (uint utilisableQuantity)
    {
        require(suppliedQuantity <= asset.quantity, "MULTIPOOL: QE");

        if (context.usdCap - (suppliedQuantity * asset.price) / DENOMINATOR != 0) {
            uint shareOld = (asset.quantity * asset.price) / context.usdCap;
            uint shareNew = ((asset.quantity - suppliedQuantity) * asset.price)
                / (context.usdCap - (suppliedQuantity * asset.price) / DENOMINATOR);
            uint targetShare = (asset.share * DENOMINATOR) / context.totalTargetShares;
            uint deviationNew = abs(shareNew, targetShare);
            uint deviationOld = abs(shareOld, targetShare);

            if (deviationNew <= deviationOld) {
                if (deviationOld != 0) {
                    uint cashback = (asset.collectedCashbacks * (deviationOld - deviationNew)) / deviationOld;
                    asset.collectedCashbacks -= cashback;
                    context.userCashbackBalance += cashback;
                }
                utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + context.operationBaseFee);
            } else {
                require(deviationNew < context.deviationLimit, "MULTIPOOL: DO");
                uint feeRatio = (context.halfDeviationFee * deviationNew * DENOMINATOR) / context.deviationLimit
                    / (context.deviationLimit - deviationNew);
                utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + feeRatio + context.operationBaseFee);

                uint depegFee =
                    suppliedQuantity - (utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR;
                uint deviationBaseFee = (context.depegBaseFee * depegFee) / DENOMINATOR;
                asset.collectedCashbacks += depegFee - deviationBaseFee;
                asset.collectedFees += deviationBaseFee;
            }
        } else {
            utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + context.operationBaseFee);
        }

        context.usdCap -= (asset.quantity * asset.price) / DENOMINATOR;
        asset.quantity -= suppliedQuantity;
        context.usdCap += (asset.quantity * asset.price) / DENOMINATOR;
        asset.collectedFees += (utilisableQuantity * context.operationBaseFee) / DENOMINATOR;
    }
}
