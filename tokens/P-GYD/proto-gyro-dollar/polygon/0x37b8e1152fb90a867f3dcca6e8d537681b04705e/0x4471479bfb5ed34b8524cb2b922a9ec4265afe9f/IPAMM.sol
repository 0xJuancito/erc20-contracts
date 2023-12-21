// SPDX-License-Identifier: LicenseRef-Gyro-1.0
// for information on licensing please see the README in the GitHub repository <https://github.com/gyrostable/core-protocol>.
pragma solidity ^0.8.4;

import "DataTypes.sol";
import "Governable.sol";

/// @title IPAMM is the pricing contract for the Primary Market
interface IPAMM {
    /// @notice this event is emitted when the system parameters are updated
    event SystemParamsUpdated(uint64 alphaBar, uint64 xuBar, uint64 thetaBar, uint64 outflowMemory);

    // NB gas optimization, don't need to use uint64
    struct Params {
        uint64 alphaBar; // ᾱ ∊ [0,1]
        uint64 xuBar; // x̄_U ∊ [0,1]
        uint64 thetaBar; // θ̄ ∊ [0,1]
        uint64 outflowMemory; // this is [0,1]
    }

    /// @notice Quotes the amount of GYD to mint for the given USD amount
    /// @param usdAmount the USD value to add to the reserve
    /// @param reserveUSDValue the current USD value of the reserve
    /// @return the amount of GYD to mint
    function computeMintAmount(uint256 usdAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256);

    /// @notice Quotes and records the amount of GYD to mint for the given USD amount.
    /// NB that reserveUSDValue is added here to future proof the implementation
    /// @param usdAmount the USD value to add to the reserve
    /// @return the amount of GYD to mint
    function mint(uint256 usdAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Quotes the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @return the USD value to redeem
    function computeRedeemAmount(uint256 gydAmount, uint256 reserveUSDValue)
        external
        view
        returns (uint256);

    /// @notice Quotes and records the output USD value given an amount of GYD
    /// @param gydAmount the amount GYD to redeem
    /// @return the USD value to redeem
    function redeem(uint256 gydAmount, uint256 reserveUSDValue) external returns (uint256);

    /// @notice Allows for the system parameters to be updated
    function setSystemParams(Params memory params) external;
}
