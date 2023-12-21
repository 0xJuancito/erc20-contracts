// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title BlacklisterRole Contract
/// @notice Only administrators can update the black lister roles
/// @dev Keeps track of black listers and can check if an account is authorized
contract BlacklisterRole is OwnerRole {
    event BlacklisterAdded(
        address indexed addedBlacklister,
        address indexed addedBy
    );
    event BlacklisterRemoved(
        address indexed removedBlacklister,
        address indexed removedBy
    );

    Role private _Blacklisters;

    /// @dev Modifier to make a function callable only when the caller is a black lister
    modifier onlyBlacklister() {
        require(isBlacklister(msg.sender), "BlacklisterRole missing");
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a black lister role
    function isBlacklister(address account) public view returns (bool) {
        return _has(_Blacklisters, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a black lister
    /// @param account The address that is guaranteed black lister authorization
    function _addBlacklister(address account) internal {
        _add(_Blacklisters, account);
        emit BlacklisterAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a black lister
    /// @param account The address removed as a black lister
    function _removeBlacklister(address account) internal {
        _remove(_Blacklisters, account);
        emit BlacklisterRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a black lister
    /// @param account The address that is guaranteed black lister authorization
    function addBlacklister(address account) external onlyOwner {
        _addBlacklister(account);
    }

    /// @dev Public function that removes an account from being a black lister
    /// @param account The address removed as a black lister
    function removeBlacklister(address account) external onlyOwner {
        _removeBlacklister(account);
    }

    uint256[49] private __gap;
}
