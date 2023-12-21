// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../roles/RevokerRole.sol";

/// @title Revocable Contract
/// @notice Only administrators can revoke tokens
/// @dev Enables reducing a balance by transfering tokens to the caller
contract Revocable is ERC20Upgradeable, RevokerRole {
    event Revoke(address indexed revoker, address indexed from, uint256 amount);

    /// @notice Only administrators should be allowed to revoke on behalf of another account
    /// @dev Revoke a quantity of token in an account, reducing the balance
    /// @param from The account tokens will be deducted from
    /// @param amount The number of tokens to remove from a balance
    function _revoke(address from, uint256 amount) internal returns (bool) {
        ERC20Upgradeable._transfer(from, msg.sender, amount);
        emit Revoke(msg.sender, from, amount);
        return true;
    }

    /// @dev Allow Revokers to revoke tokens for addresses
    /// @param from The account tokens will be deducted from
    /// @param amount The number of tokens to remove from a balance
    function revoke(address from, uint256 amount)
        external
        onlyRevoker
        returns (bool)
    {
        return _revoke(from, amount);
    }

    uint256[50] private __gap;
}
