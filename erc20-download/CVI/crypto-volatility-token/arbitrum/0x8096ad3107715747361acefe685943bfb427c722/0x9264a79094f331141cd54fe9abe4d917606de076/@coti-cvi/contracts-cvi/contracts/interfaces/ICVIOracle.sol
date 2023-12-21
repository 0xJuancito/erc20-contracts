// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface ICVIOracle {
    function getCVIRoundData(uint80 roundId) external view returns (uint32 cviValue, uint256 cviTimestamp);
    function getCVILatestRoundData() external view returns (uint32 cviValue, uint80 cviRoundId, uint256 cviTimestamp);
    function getTruncatedCVIValue(int256 cviOracleValue) external view returns (uint32);
    function getTruncatedMaxCVIValue() external view returns (uint32);
}
