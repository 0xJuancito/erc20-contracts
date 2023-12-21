// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ERC1404 {
    /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
    /// @dev Overwrite with your custom transfer restriction logic
    /// @param from Sending address
    /// @param to Receiving address
    /// @param value Amount of tokens being transferred
    /// @return Code by which to reference message for rejection reasoning
    function detectTransferRestriction(
        address from,
        address to,
        uint256 value
    ) public view virtual returns (uint8);

    /// @notice Returns a human-readable message for a given restriction code
    /// @dev Overwrite with your custom message and restrictionCode handling
    /// @param restrictionCode Identifier for looking up a message
    /// @return Text showing the restriction's reasoning
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        view
        virtual
        returns (string memory);
}
