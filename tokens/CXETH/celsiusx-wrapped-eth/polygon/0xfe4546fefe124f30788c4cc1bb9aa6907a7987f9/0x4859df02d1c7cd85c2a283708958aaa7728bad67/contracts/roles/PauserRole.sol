// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title PauserRole Contract
/// @notice Only administrators can update the pauser roles
/// @dev Keeps track of pausers and can check if an account is authorized
contract PauserRole is OwnerRole {
    event PauserAdded(address indexed addedPauser, address indexed addedBy);
    event PauserRemoved(
        address indexed removedPauser,
        address indexed removedBy
    );

    Role private _pausers;

    /// @dev Modifier to make a function callable only when the caller is a pauser
    modifier onlyPauser() {
        require(
            isPauser(msg.sender),
            "PauserRole: caller does not have the Pauser role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a pauser role
    function isPauser(address account) public view returns (bool) {
        return _has(_pausers, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a pauser
    /// @param account The address that is guaranteed pauser authorization
    function _addPauser(address account) internal {
        _add(_pausers, account);
        emit PauserAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a pauser
    /// @param account The address removed as a pauser
    function _removePauser(address account) internal {
        _remove(_pausers, account);
        emit PauserRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a pauser
    /// @param account The address that is guaranteed pauser authorization
    function addPauser(address account) external onlyOwner {
        _addPauser(account);
    }

    /// @dev Public function that removes an account from being a pauser
    /// @param account The address removed as a pauser
    function removePauser(address account) external onlyOwner {
        _removePauser(account);
    }

    uint256[49] private __gap;
}
