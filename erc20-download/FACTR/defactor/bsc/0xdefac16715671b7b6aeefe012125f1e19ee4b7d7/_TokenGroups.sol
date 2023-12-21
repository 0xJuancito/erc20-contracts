// SPDX-License-Identifier: LicenseRef-Blockwell-Smart-License
pragma solidity ^0.8.9;

import "./_Pausable.sol";
import "./_ErrorCodes.sol";
import "./_Groups.sol";

/**
 * @dev User groups for Prime Token.
 *
 * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
 */
contract TokenGroups is Pausable, ErrorCodes {
    uint8 public constant ADMIN = 1;
    uint8 public constant ATTORNEY = 2;
    uint8 public constant BUNDLER = 3;
    uint8 public constant WHITELIST = 4;
    uint8 public constant FROZEN = 5;
    uint8 public constant BW_ADMIN = 6;
    uint8 public constant SWAPPERS = 7;
    uint8 public constant DELEGATE = 8;
    uint8 public constant AUTOMATOR = 11;

    using Groups for Groups.GroupMap;

    Groups.GroupMap groups;

    event AddedToGroup(uint8 indexed groupId, address indexed account);
    event RemovedFromGroup(uint8 indexed groupId, address indexed account);

    event BwAddedAttorney(address indexed account);
    event BwRemovedAttorney(address indexed account);
    event BwRemovedAdmin(address indexed account);

    modifier onlyAdminOrAttorney() {
        expect(isAdmin(msg.sender) || isAttorney(msg.sender), ERROR_UNAUTHORIZED);
        _;
    }

    // Pausing

    /**
     * @dev Pause the contract, preventing transfers.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function pause() public whenNotPaused {
        bool attorney = isAttorney(msg.sender);
        expect(attorney || isAdmin(msg.sender), ERROR_UNAUTHORIZED);

        _pause(attorney);
    }

    /**
     * @dev Resume the contract.
     *
     * If the contract was originally paused by an attorney, only an attorney can resume.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function unpause() public whenPaused {
        if (!isAttorney(msg.sender)) {
            expect(isAdmin(msg.sender), ERROR_UNAUTHORIZED);
            expect(!pausedByAttorney(), ERROR_ATTORNEY_PAUSE);
        }
        _unpause();
    }

    // ATTORNEY

    function _addAttorney(address account) internal {
        _add(ATTORNEY, account);
    }

    function addAttorney(address account) public whenNotPaused onlyAdminOrAttorney {
        _add(ATTORNEY, account);
    }

    /**
     * @dev Allows BW admins to add an attorney to the contract in emergency cases.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function bwAddAttorney(address account) public onlyBwAdmin {
        _add(ATTORNEY, account);
        emit BwAddedAttorney(account);
    }

    function removeAttorney(address account) public whenNotPaused onlyAdminOrAttorney {
        _remove(ATTORNEY, account);
    }

    /**
     * @dev Allows BW admins to remove an attorney from the contract in emergency cases.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function bwRemoveAttorney(address account) public onlyBwAdmin {
        _remove(ATTORNEY, account);
        emit BwRemovedAttorney(account);
    }

    function isAttorney(address account) public view returns (bool) {
        return _contains(ATTORNEY, account);
    }

    // ADMIN

    function _addAdmin(address account) internal {
        _add(ADMIN, account);
    }

    function addAdmin(address account) public whenNotPaused onlyAdminOrAttorney {
        _addAdmin(account);
    }

    function removeAdmin(address account) public whenNotPaused onlyAdminOrAttorney {
        _remove(ADMIN, account);
    }

    /**
     * @dev Allows BW admins to remove an admin from the contract in emergency cases.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function bwRemoveAdmin(address account) public onlyBwAdmin {
        _remove(ADMIN, account);
        emit BwRemovedAdmin(account);
    }

    function isAdmin(address account) public view returns (bool) {
        return _contains(ADMIN, account);
    }

    // BUNDLER

    function addBundler(address account) public onlyAdminOrAttorney {
        _add(BUNDLER, account);
    }

    function removeBundler(address account) public onlyAdminOrAttorney {
        _remove(BUNDLER, account);
    }

    function isBundler(address account) public view returns (bool) {
        return _contains(BUNDLER, account);
    }

    modifier onlyBundler() {
        expect(isBundler(msg.sender), ERROR_UNAUTHORIZED);
        _;
    }

    // SWAPPERS

    function addSwapper(address account) public onlyAdminOrAttorney {
        _addSwapper(account);
    }

    function _addSwapper(address account) internal {
        _add(SWAPPERS, account);
    }

    function removeSwapper(address account) public onlyAdminOrAttorney {
        _remove(SWAPPERS, account);
    }

    function isSwapper(address account) public view returns (bool) {
        return _contains(SWAPPERS, account);
    }

    modifier onlySwapper() {
        expect(isSwapper(msg.sender), ERROR_UNAUTHORIZED);
        _;
    }

    // WHITELIST

    function addToWhitelist(address account) public onlyAdminOrAttorney {
        _add(WHITELIST, account);
    }

    function removeFromWhitelist(address account) public onlyAdminOrAttorney {
        _remove(WHITELIST, account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _contains(WHITELIST, account);
    }

    // BW_ADMIN

    function _addBwAdmin(address account) internal {
        _add(BW_ADMIN, account);
    }

    function addBwAdmin(address account) public onlyBwAdmin {
        _addBwAdmin(account);
    }

    function renounceBwAdmin() public {
        _remove(BW_ADMIN, msg.sender);
    }

    function isBwAdmin(address account) public view returns (bool) {
        return _contains(BW_ADMIN, account);
    }

    modifier onlyBwAdmin() {
        expect(isBwAdmin(msg.sender), ERROR_UNAUTHORIZED);
        _;
    }

    // FROZEN

    function _freeze(address account) internal {
        _add(FROZEN, account);
    }

    function freeze(address account) public onlyAdminOrAttorney {
        _freeze(account);
    }

    function _unfreeze(address account) internal {
        _remove(FROZEN, account);
    }

    function unfreeze(address account) public onlyAdminOrAttorney {
        _unfreeze(account);
    }

    /**
     * @dev Freeze multiple accounts with a single transaction.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiFreeze(address[] calldata account) public onlyAdminOrAttorney {
        expect(account.length > 0, ERROR_EMPTY_ARRAY);

        for (uint256 i = 0; i < account.length; i++) {
            _freeze(account[i]);
        }
    }

    /**
     * @dev Unfreeze multiple accounts with a single transaction.
     *
     * Blockwell Exclusive (Intellectual Property that lives on-chain via Smart License)
     */
    function multiUnfreeze(address[] calldata account) public onlyAdminOrAttorney {
        expect(account.length > 0, ERROR_EMPTY_ARRAY);

        for (uint256 i = 0; i < account.length; i++) {
            _unfreeze(account[i]);
        }
    }

    function isFrozen(address account) public view returns (bool) {
        return _contains(FROZEN, account);
    }

    modifier isNotFrozen() {
        expect(!isFrozen(msg.sender), ERROR_FROZEN);
        _;
    }

    // DELEGATE

    function addDelegate(address account) public onlyAdminOrAttorney {
        _add(DELEGATE, account);
    }

    function removeDelegate(address account) public onlyAdminOrAttorney {
        _remove(DELEGATE, account);
    }

    function isDelegate(address account) public view returns (bool) {
        return _contains(DELEGATE, account);
    }

    // AUTOMATOR

    function addAutomator(address account) public onlyAdminOrAttorney {
        _add(AUTOMATOR, account);
    }

    function removeAutomator(address account) public onlyAdminOrAttorney {
        _remove(AUTOMATOR, account);
    }

    function isAutomator(address account) public view returns (bool) {
        return _contains(AUTOMATOR, account);
    }

    // Internal functions

    function _add(uint8 groupId, address account) internal {
        groups.add(groupId, account);
        emit AddedToGroup(groupId, account);
    }

    function _remove(uint8 groupId, address account) internal {
        groups.remove(groupId, account);
        emit RemovedFromGroup(groupId, account);
    }

    function _contains(uint8 groupId, address account) internal view returns (bool) {
        return groups.contains(groupId, account);
    }
}
