// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./ICVIOracle.sol";
import "./IFundingFeeAdjuster.sol";

interface IFeesCalculator {

    struct CVIValue {
        uint256 period;
        uint32 positionCVIValue;
        uint32 fundingFeeCVIValue;
    }

    struct SnapshotUpdate {
        uint256 latestSnapshot;
        uint256 singleUnitFundingFee;
        uint256 cviValueTimestamp;
        uint80 newLatestRoundId;
        uint32 cviValue;
        bool updatedSnapshot;
        bool updatedLatestRoundId;
        bool updatedLatestTimestamp;
    }

    function calculateBuyingPremiumFee(uint168 tokenAmount, uint8 leverage, uint32 openPositionLPFeePercentDeduction, uint256 lastTotalLeveragedTokens, uint256 lastTotalPositionUnits, uint256 totalLeveragedTokens, uint256 totalPositionUnits) external view returns (uint168 buyingPremiumFee, uint32 combinedPremiumFeePercentage);

    function calculateSingleUnitFundingFee(CVIValue[] memory cviValues) external view returns (uint256 fundingFee);
    function calculateSingleUnitPeriodFundingFee(CVIValue memory cviValue) external view returns (uint256 fundingFee, uint256 fundingFeeRatePercents);
    function updateSnapshots(uint256 latestTimestamp, uint256 blockTimestampSnapshot, uint256 latestTimestampSnapshot, uint80 latestOracleRoundId) external view returns (SnapshotUpdate memory snapshotUpdate);

    function calculateWithdrawFeePercent(uint256 lastDepositTimestamp) external view returns (uint32);

    function calculateCollateralRatio(uint256 totalLeveragedTokens, uint256 totalPositionUnits) external view returns (uint256 collateralRatio);

    function depositFeePercent() external view returns (uint32);
    function withdrawFeePercent() external view returns (uint32);
    function openPositionFeePercent() external view returns (uint32);
    function closePositionFeePercent() external view returns (uint32);
    function openPositionLPFeePercent() external view returns (uint32);
    function closePositionLPFeePercent() external view returns (uint32);
    function buyingPremiumFeeMaxPercent() external view returns (uint32);

    function openPositionFees(bytes32 referralCode) external view returns (uint32 openPositionFeePercentResult, address affiliate, uint32 affiliatePositionFeePercent, uint32 openPositionLPFeeReductionPercent);
    function closePositionFees(bytes32 referralCode) external view returns (uint32 closePositionFeePercentResult, uint32 closePremiumFeePercentResult, address affiliate, uint32 affiliatePositionFeePercent);
    function setTraderReferralCode(bytes32 referralCode, address trader) external;

    function getCollateralToBuyingPremiumMapping() external view returns (uint32[] memory);
    function feesCVIOracle() external view returns (ICVIOracle);
    function fundingFeeAdjuster() external view returns (IFundingFeeAdjuster);
}
