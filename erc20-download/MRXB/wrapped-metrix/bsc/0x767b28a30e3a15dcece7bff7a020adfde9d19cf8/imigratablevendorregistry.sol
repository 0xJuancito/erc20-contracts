// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/// A collection of all methods on a previous VendorRegistry called by the new version of WrappedAsset during migration.
/// The migration process does not use any VendorRegistry methods on the previous version that are not in this interface.
interface IMigratableVendorRegistry
    {
    /// Look up the MRX addrees for a given (ethereum or BSC) vendor address.
    /// @param  vendorAddress The vendor address address for which to look up the MRX address.
    /// @return The MRX address, or address(0) if the vendor address is not registered.
    function findMrxFromVendor(address vendorAddress) external view returns (address);
    }
