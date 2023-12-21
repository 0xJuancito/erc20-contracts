// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../roles/WhitelisterRole.sol";

/// @title Whitelistable Contract
/// @notice Only administrators can update the white lists, and any address can only be a member of one whitelist at a
/// time
/// @dev Keeps track of white lists and can check if sender and reciever are configured to allow a transfer
contract Whitelistable is WhitelisterRole {
    // The mapping to keep track of which whitelist any address belongs to.
    // 0 is reserved for no whitelist and is the default for all addresses.
    mapping(address => uint8) public addressWhitelists;

    // The mapping to keep track of each whitelist's outbound whitelist flags.
    // Boolean flag indicates whether outbound transfers are enabled.
    mapping(uint8 => mapping(uint8 => bool)) public outboundWhitelistsEnabled;

    // Track whether whitelisting is enabled
    bool public isWhitelistEnabled;

    // Zero is reserved for indicating it is not on a whitelist
    uint8 constant NO_WHITELIST = 0;

    // Events to allow tracking add/remove.
    event AddressAddedToWhitelist(
        address indexed addedAddress,
        uint8 indexed whitelist,
        address indexed addedBy
    );
    event AddressRemovedFromWhitelist(
        address indexed removedAddress,
        uint8 indexed whitelist,
        address indexed removedBy
    );
    event OutboundWhitelistUpdated(
        address indexed updatedBy,
        uint8 indexed sourceWhitelist,
        uint8 indexed destinationWhitelist,
        bool from,
        bool to
    );
    event WhitelistEnabledUpdated(
        address indexed updatedBy,
        bool indexed enabled
    );

    /// @notice Only administrators should be allowed to update this
    /// @dev Enable or disable the whitelist enforcement
    /// @param enabled A boolean flag that enables token transfers to be white listed
    function _setWhitelistEnabled(bool enabled) internal {
        isWhitelistEnabled = enabled;
        emit WhitelistEnabledUpdated(msg.sender, enabled);
    }

    /// @notice Only administrators should be allowed to update this. If an address is on an existing whitelist, it will
    /// just get updated to the new value (removed from previous)
    /// @dev Sets an address's white list ID.
    /// @param addressToAdd The address added to a whitelist
    /// @param whitelist Number identifier for the whitelist the address is being added to
    function _addToWhitelist(address addressToAdd, uint8 whitelist) internal {
        // Verify a valid address was passed in
        require(
            addressToAdd != address(0),
            "Cannot add address 0x0 to a whitelist."
        );

        // Verify the whitelist is valid
        require(whitelist != NO_WHITELIST, "Invalid whitelist ID supplied");

        // Save off the previous white list
        uint8 previousWhitelist = addressWhitelists[addressToAdd];

        // Set the address's white list ID
        addressWhitelists[addressToAdd] = whitelist;

        // If the previous whitelist existed then we want to indicate it has been removed
        if (previousWhitelist != NO_WHITELIST) {
            // Emit the event for tracking
            emit AddressRemovedFromWhitelist(
                addressToAdd,
                previousWhitelist,
                msg.sender
            );
        }

        // Emit the event for new whitelist
        emit AddressAddedToWhitelist(addressToAdd, whitelist, msg.sender);
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Clears out an address's white list ID
    /// @param addressToRemove The address removed from a white list
    function _removeFromWhitelist(address addressToRemove) internal {
        // Verify a valid address was passed in
        require(
            addressToRemove != address(0),
            "Cannot remove address 0x0 from a whitelist."
        );

        // Save off the previous white list
        uint8 previousWhitelist = addressWhitelists[addressToRemove];

        // Verify the address was actually on a whitelist
        require(
            previousWhitelist != NO_WHITELIST,
            "Address cannot be removed from invalid whitelist."
        );

        // Zero out the previous white list
        addressWhitelists[addressToRemove] = NO_WHITELIST;

        // Emit the event for tracking
        emit AddressRemovedFromWhitelist(
            addressToRemove,
            previousWhitelist,
            msg.sender
        );
    }

    /// @notice Only administrators should be allowed to update this
    /// @dev Sets the flag to indicate whether source whitelist is allowed to send to destination whitelist
    /// @param sourceWhitelist The white list of the sender
    /// @param destinationWhitelist The white list of the receiver
    /// @param newEnabledValue A boolean flag that enables token transfers between white lists
    function _updateOutboundWhitelistEnabled(
        uint8 sourceWhitelist,
        uint8 destinationWhitelist,
        bool newEnabledValue
    ) internal {
        // Get the old enabled flag
        bool oldEnabledValue = outboundWhitelistsEnabled[sourceWhitelist][
            destinationWhitelist
        ];

        // Update to the new value
        outboundWhitelistsEnabled[sourceWhitelist][
            destinationWhitelist
        ] = newEnabledValue;

        // Emit event for tracking
        emit OutboundWhitelistUpdated(
            msg.sender,
            sourceWhitelist,
            destinationWhitelist,
            oldEnabledValue,
            newEnabledValue
        );
    }

    /// @notice The source whitelist must be enabled to send to the whitelist where the receive exists
    /// @dev Determine if the a sender is allowed to send to the receiver
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    function checkWhitelistAllowed(address sender, address receiver)
        public
        view
        returns (bool)
    {
        // If whitelist enforcement is not enabled, then allow all
        if (!isWhitelistEnabled) {
            return true;
        }

        // First get each address white list
        uint8 senderWhiteList = addressWhitelists[sender];
        uint8 receiverWhiteList = addressWhitelists[receiver];

        // If either address is not on a white list then the check should fail
        if (
            senderWhiteList == NO_WHITELIST || receiverWhiteList == NO_WHITELIST
        ) {
            return false;
        }

        // Determine if the sending whitelist is allowed to send to the destination whitelist
        return outboundWhitelistsEnabled[senderWhiteList][receiverWhiteList];
    }

    /// @dev Public function that enables or disables the white list enforcement
    /// @param enabled A boolean flag that enables token transfers to be whitelisted
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        _setWhitelistEnabled(enabled);
    }

    /// @notice If an address is on an existing whitelist, it will just get updated to the new value (removed from
    /// previous)
    /// @dev Public function that sets an address's white list ID
    /// @param addressToAdd The address added to a whitelist
    /// @param whitelist Number identifier for the whitelist the address is being added to
    function addToWhitelist(address addressToAdd, uint8 whitelist)
        external
        onlyWhitelister
    {
        _addToWhitelist(addressToAdd, whitelist);
    }

    /// @dev Public function that clears out an address's white list ID
    /// @param addressToRemove The address removed from a white list
    function removeFromWhitelist(address addressToRemove)
        external
        onlyWhitelister
    {
        _removeFromWhitelist(addressToRemove);
    }

    /// @dev Public function that sets the flag to indicate whether source white list is allowed to send to destination
    /// white list
    /// @param sourceWhitelist The white list of the sender
    /// @param destinationWhitelist The white list of the receiver
    /// @param newEnabledValue A boolean flag that enables token transfers between white lists
    function updateOutboundWhitelistEnabled(
        uint8 sourceWhitelist,
        uint8 destinationWhitelist,
        bool newEnabledValue
    ) external onlyWhitelister {
        _updateOutboundWhitelistEnabled(
            sourceWhitelist,
            destinationWhitelist,
            newEnabledValue
        );
    }

    uint256[47] private __gap;
}
