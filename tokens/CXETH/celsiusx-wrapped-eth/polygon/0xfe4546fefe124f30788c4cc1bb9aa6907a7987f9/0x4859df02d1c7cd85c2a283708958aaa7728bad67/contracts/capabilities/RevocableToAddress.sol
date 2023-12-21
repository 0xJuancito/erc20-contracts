// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../roles/RevokerRole.sol";

/// @title RevocableToAddress Contract
/// @notice Only administrators can revoke tokens to an address
/// @dev Enables reducing a balance by transfering tokens to an address
contract RevocableToAddress is ERC20Upgradeable, RevokerRole {
    event RevokeToAddress(
        address indexed revoker,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /// @notice Only administrators should be allowed to revoke on behalf of another account
    /// @dev Revoke a quantity of token in an account, reducing the balance
    /// @param from The account tokens will be deducted from
    /// @param to The account revoked token will be transferred to
    /// @param amount The number of tokens to remove from a balance
    function _revokeToAddress(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        ERC20Upgradeable._transfer(from, to, amount);
        emit RevokeToAddress(msg.sender, from, to, amount);
        return true;
    }

    /**
    Allow Admins to revoke tokens from any address to any destination
    */

    /// @notice Only administrators should be allowed to revoke on behalf of another account
    /// @dev Revoke a quantity of token in an account, reducing the balance
    /// @param from The account tokens will be deducted from
    /// @param amount The number of tokens to remove from a balance
    function revokeToAddress(
        address from,
        address to,
        uint256 amount
    ) external onlyRevoker returns (bool) {
        return _revokeToAddress(from, to, amount);
    }

    uint256[50] private __gap;
}
