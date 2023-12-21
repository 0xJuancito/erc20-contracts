// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnerRole.sol";

/// @title BurnerRole Contract
/// @notice Only administrators can update the burner roles
/// @dev Keeps track of burners and can check if an account is authorized
contract BurnerRole is OwnerRole {
    event BurnerAdded(address indexed addedBurner, address indexed addedBy);
    event BurnerRemoved(
        address indexed removedBurner,
        address indexed removedBy
    );

    Role private _burners;

    /// @dev Modifier to make a function callable only when the caller is a burner
    modifier onlyBurner() {
        require(
            isBurner(msg.sender),
            "BurnerRole: caller does not have the Burner role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted a burner role
    function isBurner(address account) public view returns (bool) {
        return _has(_burners, account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as a burner
    /// @param account The address that is guaranteed burner authorization
    function _addBurner(address account) internal {
        _add(_burners, account);
        emit BurnerAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being a burner
    /// @param account The address removed as a burner
    function _removeBurner(address account) internal {
        _remove(_burners, account);
        emit BurnerRemoved(account, msg.sender);
    }

    /// @dev Public function that adds an address as a burner
    /// @param account The address that is guaranteed burner authorization
    function addBurner(address account) external onlyOwner {
        _addBurner(account);
    }

    /// @dev Public function that removes an account from being a burner
    /// @param account The address removed as a burner
    function removeBurner(address account) external onlyOwner {
        _removeBurner(account);
    }

    uint256[49] private __gap;
}
