// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./ICVIOracle.sol";

interface IThetaVaultInfo {
    function platformPositionUnits() external view returns (uint256);
    function vaultPositionUnits() external view returns (uint256);
    function extraLiquidityPercentage() external view returns (uint32);
    function minDexPercentageAllowed() external view returns (uint16);

    function oracle() external view returns (ICVIOracle);
}
