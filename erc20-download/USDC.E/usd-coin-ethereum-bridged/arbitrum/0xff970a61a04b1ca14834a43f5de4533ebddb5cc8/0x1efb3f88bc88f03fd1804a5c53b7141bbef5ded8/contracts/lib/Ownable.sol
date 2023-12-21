// SPDX-License-Identifier: MIT
// Copyright (c) 2021 Coinbase, Inc.

pragma solidity 0.6.12;

/**
 * @notice Ownable
 * @dev Similar to OpenZeppelin's Ownable.
 * Differences:
 * - An internally callable _changeOwner() function
 * - No renounceOwnership() function
 * - No constructor
 * - No GSN support
 */
abstract contract Ownable {
    address internal _owner;

    /**
     * @notice Emitted when the owner changes.
     * @param previousOwner Previous owner's address
     * @param newOwner New owner's address
     */
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Throw if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "caller is not the owner");
        _;
    }

    /**
     * @notice Return the address of the current owner.
     * @return Owner's address
     */
    function owner() external view returns (address) {
        return _owner;
    }

    /**
     * @notice Change the owner. Can only be called by the current owner.
     * @param account New owner's address
     */
    function changeOwner(address account) external onlyOwner {
        _changeOwner(account);
    }

    /**
     * @notice Internal function to change the owner.
     * @param account New owner's address
     */
    function _changeOwner(address account) internal {
        require(account != address(0), "account is the zero address");
        require(account != address(this), "account is this contract");
        emit OwnerChanged(_owner, account);
        _owner = account;
    }
}
