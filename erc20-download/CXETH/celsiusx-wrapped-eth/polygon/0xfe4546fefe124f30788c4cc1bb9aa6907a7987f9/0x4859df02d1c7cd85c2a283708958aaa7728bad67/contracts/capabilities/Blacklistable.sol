// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../roles/BlacklisterRole.sol";

/// @title Blacklistable Contract
/// @notice Only administrators can update the black list
/// @dev Keeps track of black lists and can check if sender and reciever are configured to allow a transfer
contract Blacklistable is BlacklisterRole {
    // The mapping to keep track if an address is black listed
    mapping(address => bool) public addressBlacklists;

    // Track whether Blacklisting is enabled
    bool public isBlacklistEnabled;

    // Events to allow tracking add/remove.
    event AddressAddedToBlacklist(
        address indexed addedAddress,
        address indexed addedBy
    );
    event AddressRemovedFromBlacklist(
        address indexed removedAddress,
        address indexed removedBy
    );
    event BlacklistEnabledUpdated(
        address indexed updatedBy,
        bool indexed enabled
    );

    /// @notice Only administrators should be allowed to update this
    /// @dev Enable or disable the black list enforcement
    /// @param enabled A boolean flag that enables token transfers to be black listed
    function _setBlacklistEnabled(bool enabled) internal {
        isBlacklistEnabled = enabled;
        emit BlacklistEnabledUpdated(msg.sender, enabled);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Sets an address's black listing status
    /// @param addressToAdd The address added to a black list
    function _addToBlacklist(address addressToAdd) internal {
        // Verify a valid address was passed in
        require(addressToAdd != address(0), "Cannot add 0x0");

        // Verify the address is on the blacklist before it can be removed
        require(!addressBlacklists[addressToAdd], "Already on list");

        // Set the address's white list ID
        addressBlacklists[addressToAdd] = true;

        // Emit the event for new Blacklist
        emit AddressAddedToBlacklist(addressToAdd, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Clears out an address from the black list
    /// @param addressToRemove The address removed from a black list
    function _removeFromBlacklist(address addressToRemove) internal {
        // Verify a valid address was passed in
        require(addressToRemove != address(0), "Cannot remove 0x0");

        // Verify the address is on the blacklist before it can be removed
        require(addressBlacklists[addressToRemove], "Not on list");

        // Zero out the previous white list
        addressBlacklists[addressToRemove] = false;

        // Emit the event for tracking
        emit AddressRemovedFromBlacklist(addressToRemove, msg.sender);
    }

    /// @notice If either the sender or receiver is black listed, then the transfer should be denied
    /// @dev Determine if the a sender is allowed to send to the receiver
    /// @param sender The sender of a token transfer
    /// @param receiver The receiver of a token transfer
    function checkBlacklistAllowed(address sender, address receiver)
        public
        view
        returns (bool)
    {
        // If black list enforcement is not enabled, then allow all
        if (!isBlacklistEnabled) {
            return true;
        }

        // If either address is on the black list then fail
        return !addressBlacklists[sender] && !addressBlacklists[receiver];
    }

    /// @dev Public function that enables or disables the black list enforcement
    /// @param enabled A boolean flag that enables token transfers to be black listed
    function setBlacklistEnabled(bool enabled) external onlyOwner {
        _setBlacklistEnabled(enabled);
    }

    /// @dev Public function that allows admins to remove an address from a black list
    /// @param addressToAdd The address added to a black list
    function addToBlacklist(address addressToAdd) external onlyBlacklister {
        _addToBlacklist(addressToAdd);
    }

    /// @dev Public function that allows admins to remove an address from a black list
    /// @param addressToRemove The address removed from a black list
    function removeFromBlacklist(address addressToRemove)
        external
        onlyBlacklister
    {
        _removeFromBlacklist(addressToRemove);
    }

    uint256[48] private __gap;
}
