// SPDX-License-Identifier: MIT
// Copyright (c) 2021 Coinbase, Inc.

pragma solidity 0.6.12;

import { Ownable } from "./Ownable.sol";

/**
 * @notice Pausable
 * @dev Similar to OpenZeppelin's Pausable.
 * Differences:
 * - Has the pauser role
 * - External pause/unpause functions callable by the pauser
 * - No constructor
 * - No GSN support
 */
abstract contract Pausable is Ownable {
    address private _pauser;
    bool private _paused;

    /**
     * @notice Emitted when the pauser changes.
     * @param previousPauser Previous pauser's address
     * @param newPauser New pauser's address
     */
    event PauserChanged(
        address indexed previousPauser,
        address indexed newPauser
    );

    /**
     * @notice Emitted when the contract is paused.
     * @param pauser Pauser's address
     */
    event Paused(address pauser);

    /**
     * @notice Emitted when the contract is unpaused.
     * @param pauser Pauser's address
     */
    event Unpaused(address pauser);

    /**
     * @notice Callable only by the pauser.
     */
    modifier onlyPauser() {
        require(msg.sender == _pauser, "caller is not the pauser");
        _;
    }

    /**
     * @notice Callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "contract is paused");
        _;
    }

    /**
     * @notice Callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "contract is not paused");
        _;
    }

    /**
     * @notice Return the current pauser.
     * @return Pauser's address
     */
    function pauser() external view returns (address) {
        return _pauser;
    }

    /**
     * @notice Return whether the contract is paused.
     * @return True if paused
     */
    function paused() external view returns (bool) {
        return _paused;
    }

    /**
     * @notice Pause the contract.
     */
    function pause() external onlyPauser {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract.
     */
    function unpause() external onlyPauser {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Set a new pauser.
     * @param account New pauser's address
     */
    function setPauser(address account) external onlyOwner {
        _setPauser(account);
    }

    /**
     * @notice Initial function to set the pauser.
     * @param account New pauser's address
     */
    function _setPauser(address account) internal {
        emit PauserChanged(_pauser, account);
        _pauser = account;
    }
}
