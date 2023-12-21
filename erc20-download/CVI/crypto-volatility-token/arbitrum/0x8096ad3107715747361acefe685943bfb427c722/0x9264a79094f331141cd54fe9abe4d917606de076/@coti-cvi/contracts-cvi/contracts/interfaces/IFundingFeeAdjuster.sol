// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface IFundingFeeAdjuster {

    function calculateFundingFeePercentage(uint32 cviValue, bool isReverse, uint32 fundingFeeMultiplier) external view returns (uint256 fundingFeeRatePercents);
    function calculateFundingFeePercentage(uint32 cviValue, uint32 fundingFeeMultiplier, uint32 multiplier) external view returns (uint256 fundingFeeRatePercents);
    function getFundingFeeCoefficients() external view returns(uint32[] memory);

    function fundingFeeMaxRate() external view returns (uint32);

    function fundingFeeLongMultiplier() external view returns (uint32);
    function fundingFeeShortMultiplier() external view returns (uint32);

    function fundingFeeMinShortRate() external view returns (uint32);
    function fundingFeeShortRange() external view returns (uint32);
}
