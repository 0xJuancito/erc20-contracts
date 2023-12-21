// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity =0.8.9;
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract OEPausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event PausedDeposit(address account);
    event PausedWithdraw(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event UnpausedDeposit(address account);
    event UnpausedWithdraw(address account);

    bool private _pausedDeposit;
    bool private _pausedWithdraw;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */

    modifier whenNotPausedDeposit() {
        _requireNotPausedDeposit();
        _;
    }

    modifier whenNotPausedWithdraw() {
        _requireNotPausedWithdraw();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPausedDeposit() {
        _requirePausedDeposit();
        _;
    }

    modifier whenPausedWithdraw() {
        _requirePausedWithdraw();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function pausedDeposit() public view virtual returns (bool) {
        return _pausedDeposit;
    }

    function pausedWithdraw() public view virtual returns (bool) {
        return _pausedWithdraw;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPausedWithdraw() internal view virtual {
        require(!pausedWithdraw(), "Pausable: withdraw paused");
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPausedDeposit() internal view virtual {
        require(!pausedDeposit(), "Pausable: deposit paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePausedDeposit() internal view virtual {
        require(pausedDeposit(), "Pausable: deposit not paused");
    }

    function _requirePausedWithdraw() internal view virtual {
        require(pausedWithdraw(), "Pausable: withdraw not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pauseDeposit() internal virtual whenNotPausedDeposit {
        _pausedDeposit = true;
        emit PausedDeposit(_msgSender());
    }

    function _pauseWithdraw() internal virtual whenNotPausedWithdraw {
        _pausedWithdraw = true;
        emit PausedWithdraw(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpauseDeposit() internal virtual whenPausedDeposit {
        _pausedDeposit = false;
        emit UnpausedDeposit(_msgSender());
    }

    function _unpauseWithdraw() internal virtual whenPausedWithdraw {
        _pausedWithdraw = false;
        emit UnpausedWithdraw(_msgSender());
    }
}
