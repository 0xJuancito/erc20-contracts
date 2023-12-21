// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface ILiquidityManageable {
    function setLiquidityManagementPhase(bool _isManagingLiquidity) external;

    function isLiquidityManager(address _addr) external returns (bool);

    function isLiquidityManagementPhase() external returns (bool);
}
