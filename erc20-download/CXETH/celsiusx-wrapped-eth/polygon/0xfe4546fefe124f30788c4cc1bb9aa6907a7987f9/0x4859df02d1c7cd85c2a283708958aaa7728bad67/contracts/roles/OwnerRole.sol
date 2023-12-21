// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title OwnerRole Contract
/// @notice Only administrators can update the owner roles
/// @dev Keeps track of owners and can check if an account is authorized
contract OwnerRole {
    event OwnerAdded(address indexed addedOwner, address indexed addedBy);
    event OwnerRemoved(address indexed removedOwner, address indexed removedBy);

    struct Role {
        mapping(address => bool) members;
    }

    Role private _owners;

    /// @dev Modifier to make a function callable only when the caller is an owner
    modifier onlyOwner() {
        require(
            isOwner(msg.sender),
            "OwnerRole: caller does not have the Owner role"
        );
        _;
    }

    /// @dev Public function returns `true` if `account` has been granted an owner role
    function isOwner(address account) public view returns (bool) {
        return _has(_owners, account);
    }

    /// @dev Public function that adds an address as an owner
    /// @param account The address that is guaranteed owner authorization
    function addOwner(address account) external onlyOwner {
        _addOwner(account);
    }

    /// @dev Public function that removes an account from being an owner
    /// @param account The address removed as a owner
    function removeOwner(address account) external onlyOwner {
        _removeOwner(account);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Adds an address as an owner
    /// @param account The address that is guaranteed owner authorization
    function _addOwner(address account) internal {
        _add(_owners, account);
        emit OwnerAdded(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Removes an account from being an owner
    /// @param account The address removed as an owner
    function _removeOwner(address account) internal {
        _remove(_owners, account);
        emit OwnerRemoved(account, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Give an account access to this role
    /// @param role All authorizations for the contract
    /// @param account The address that is guaranteed owner authorization
    function _add(Role storage role, address account) internal {
        require(account != address(0x0), "Invalid 0x0 address");
        require(!_has(role, account), "Roles: account already has role");
        role.members[account] = true;
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Remove an account's access to this role
    /// @param role All authorizations for the contract
    /// @param account The address that is guaranteed owner authorization
    function _remove(Role storage role, address account) internal {
        require(_has(role, account), "Roles: account does not have role");
        role.members[account] = false;
    }

    /// @dev Check if an account is in the set of roles
    /// @param role All authorizations for the contract
    /// @param account The address that is guaranteed owner authorization
    /// @return boolean
    function _has(Role storage role, address account)
        internal
        view
        returns (bool)
    {
        require(account != address(0), "Roles: account is the zero address");
        return role.members[account];
    }

    uint256[49] private __gap;
}
