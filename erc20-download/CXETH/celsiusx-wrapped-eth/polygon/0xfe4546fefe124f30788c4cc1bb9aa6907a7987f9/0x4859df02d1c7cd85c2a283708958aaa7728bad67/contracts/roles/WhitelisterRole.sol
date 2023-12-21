// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title WhitelisterRole Contract
/// @notice Only administrators can update the white lister roles
/// @dev Keeps track of white listers and can check if an account is authorized
contract WhitelisterRole is OwnerRole {
    event WhitelisterAdded(
        address indexed addedWhitelister,
        address indexed addedBy
    );
    event WhitelisterRemoved(
        address indexed removedWhitelister,
        address indexed removedBy
    );

    Role private _whitelisters;

    /// @dev Modifier to make a function callable only when the caller is a white lister
    modifier onlyWhitelister() {
        require(
            isWhitelister(msg.sender),
            "WhitelisterRole: caller does not have the Whitelister role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a white lister role
    function isWhitelister(address account) public view returns (bool) {
        return _has(_whitelisters, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a white lister
    /// @param account The address that is guaranteed white lister authorization
    function _addWhitelister(address account) internal {
        _add(_whitelisters, account);
        emit WhitelisterAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a white lister
    /// @param account The address removed as a white lister
    function _removeWhitelister(address account) internal {
        _remove(_whitelisters, account);
        emit WhitelisterRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a white lister
    /// @param account The address that is guaranteed white lister authorization
    function addWhitelister(address account) external onlyOwner {
        _addWhitelister(account);
    }

    /// @dev Public function that removes an account from being a white lister
    /// @param account The address removed as a white lister
    function removeWhitelister(address account) external onlyOwner {
        _removeWhitelister(account);
    }

    uint256[49] private __gap;
}
