// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IOracle {
    function convertUsdBalanceDecimalToTokenDecimal(uint256 _balanceUsdDecimal) external view returns (uint256);

    function setUsdtAmount(uint256 _usdtAmount) external;

    function setTokenAmount(uint256 _tokenAmount) external;

    function setMinTokenAmount(uint256 _tokenAmount) external;

    function setMaxTokenAmount(uint256 _tokenAmount) external;
}
