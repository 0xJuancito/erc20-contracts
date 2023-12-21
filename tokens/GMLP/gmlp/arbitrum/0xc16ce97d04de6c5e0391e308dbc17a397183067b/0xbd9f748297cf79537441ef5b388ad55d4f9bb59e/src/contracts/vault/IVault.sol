// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// Vault Interface
interface IVault {
    function getAmountAcrossStrategies(
        address coin
    ) external view returns (uint256 value);

    function debt(address coin) external view returns (uint256 value);
}
