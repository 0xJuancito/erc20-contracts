// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

interface IVaultWeightManager {
    /// @notice Retrieves the weight of the given vault
    function getVaultWeight(address _vault) external view returns (uint256);

    /// @notice Retrieves the weights of the given vaults
    function getVaultWeights(address[] calldata _vaults) external view returns (uint256[] memory);

    /// @notice Sets the weight of the given vault
    function setVaultWeight(address _vault, uint256 _weight) external;
}
