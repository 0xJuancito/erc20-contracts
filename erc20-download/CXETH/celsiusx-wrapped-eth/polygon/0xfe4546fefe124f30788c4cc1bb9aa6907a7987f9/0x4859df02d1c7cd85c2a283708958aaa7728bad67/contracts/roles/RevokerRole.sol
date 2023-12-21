// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title RevokerRole Contract
/// @notice Only administrators can update the revoker roles
/// @dev Keeps track of revokers and can check if an account is authorized
contract RevokerRole is OwnerRole {
    event RevokerAdded(address indexed addedRevoker, address indexed addedBy);
    event RevokerRemoved(
        address indexed removedRevoker,
        address indexed removedBy
    );

    Role private _revokers;

    /// @dev Modifier to make a function callable only when the caller is a revoker
    modifier onlyRevoker() {
        require(
            isRevoker(msg.sender),
            "RevokerRole: caller does not have the Revoker role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a revoker role
    function isRevoker(address account) public view returns (bool) {
        return _has(_revokers, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a revoker
    /// @param account The address that is guaranteed revoker authorization
    function _addRevoker(address account) internal {
        _add(_revokers, account);
        emit RevokerAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a revoker
    /// @param account The address removed as a revoker
    function _removeRevoker(address account) internal {
        _remove(_revokers, account);
        emit RevokerRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a revoker
    /// @param account The address that is guaranteed revoker authorization
    function addRevoker(address account) external onlyOwner {
        _addRevoker(account);
    }

    /// @dev Public function that removes an account from being a revoker
    /// @param account The address removed as a revoker
    function removeRevoker(address account) external onlyOwner {
        _removeRevoker(account);
    }

    uint256[49] private __gap;
}
