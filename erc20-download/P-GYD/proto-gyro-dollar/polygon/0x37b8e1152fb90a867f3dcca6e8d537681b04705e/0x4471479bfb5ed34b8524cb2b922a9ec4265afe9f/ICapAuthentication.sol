// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice ICapAuthentication handles cap authentication for the capped protocol
interface ICapAuthentication {
    /// @return `true` if the account is authenticated
    function isAuthenticated(address account) external view returns (bool);
}
