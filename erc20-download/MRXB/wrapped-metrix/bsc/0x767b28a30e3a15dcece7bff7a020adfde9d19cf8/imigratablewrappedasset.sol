// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/// A collection of all methods on a previous WrappedAsset called by the new version of WrappedAsset during migration.
/// The migration process does not use any WrappedAsset methods on the previous version that are not in this interface.
interface IMigratableWrappedAsset
    {
    /// Only called by the next version of WrappedAsset during migration, this method deducts a maximum amount or its total value (whichever is less) from the given account.
    /// @param   account   The account from which to remove the wrapped MRX.
    /// @param   maxAmount The maximum amount to deduct in satoshi.
    /// @return The amount of MRX actually removed.
    function migrationBurn(address account, uint256 maxAmount) external returns (uint256);
    }
