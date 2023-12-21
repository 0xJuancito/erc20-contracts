// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title MinterRole Contract
/// @notice Only administrators can update the minter roles
/// @dev Keeps track of minters and can check if an account is authorized
contract MinterRole is OwnerRole {
    event MinterAdded(address indexed addedMinter, address indexed addedBy);
    event MinterRemoved(
        address indexed removedMinter,
        address indexed removedBy
    );

    Role private _minters;

    /// @dev Modifier to make a function callable only when the caller is a minter
    modifier onlyMinter() {
        require(
            isMinter(msg.sender),
            "MinterRole: caller does not have the Minter role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a minter role
    function isMinter(address account) public view returns (bool) {
        return _has(_minters, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a minter
    /// @param account The address that is guaranteed minter authorization
    function _addMinter(address account) internal {
        _add(_minters, account);
        emit MinterAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a minter
    /// @param account The address removed as a minter
    function _removeMinter(address account) internal {
        _remove(_minters, account);
        emit MinterRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a minter
    /// @param account The address that is guaranteed minter authorization
    function addMinter(address account) external onlyOwner {
        _addMinter(account);
    }

    /// @dev Public function that removes an account from being a minter
    /// @param account The address removed as a minter
    function removeMinter(address account) external onlyOwner {
        _removeMinter(account);
    }

    uint256[49] private __gap;
}
