// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "ERC165.sol";

import "Context.sol";
import "AccessConstants.sol";
import "IViciAccess.sol";
import {IAccessServer} from "IAccessServer.sol";

/**
 * @title ViciAccess
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev This contract implements OpenZeppelin's IAccessControl and
 * IAccessControlEnumerable interfaces as well as the behavior of their
 * Ownable contract.
 * @dev The differences are:
 * - Use of an external AccessServer contract to track roles and ownership.
 * - Support for OFAC sanctions compliance
 * - Support for a negative BANNED role
 * - A contract owner is automatically granted the DEFAULT ADMIN role.
 * - Contract owner cannot renounce ownership, can only transfer it.
 * - DEFAULT ADMIN role cannot be revoked from the Contract owner, nor can they
 *   renouce that role.
 * @dev see `AccessControl`, `AccessControlEnumerable`, and `Ownable` for
 * additional documentation.
 */
abstract contract ViciAccess is Context, IViciAccess, ERC165 {
    IAccessServer public accessServer;

    bytes32 public constant DEFAULT_ADMIN_ROLE = DEFAULT_ADMIN;

    // Role for banned users.
    bytes32 public constant BANNED_ROLE_NAME = BANNED;

    // Role for moderator.
    bytes32 public constant MODERATOR_ROLE_NAME = MODERATOR;

    /* ################################################################
     * Initialization
     * ##############################################################*/

    function __ViciAccess_init(
        IAccessServer _accessServer
    ) internal onlyInitializing {
        __ViciAccess_init_unchained(_accessServer);
    }

    function __ViciAccess_init_unchained(
        IAccessServer _accessServer
    ) internal onlyInitializing {
        accessServer = _accessServer;
        accessServer.register(_msgSender());
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            interfaceId == type(IAccessControlEnumerable).interfaceId ||
            ERC165.supportsInterface(interfaceId);
    }

    /* ################################################################
     * Checking Roles
     * ##############################################################*/

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev reverts if called by an account that is not the owner and doesn't
     *     have the required role.
     */
    modifier onlyOwnerOrRole(bytes32 role) {
        enforceOwnerOrRole(role, _msgSender());
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        accessServer.enforceIsMyOwner(_msgSender());
        _;
    }

    /**
     * @dev reverts if the caller is banned or on the OFAC sanctions list.
     */
    modifier noBannedAccounts() {
        enforceIsNotBanned(_msgSender());
        _;
    }

    /**
     * @dev reverts if the account is banned or on the OFAC sanctions list.
     */
    modifier notBanned(address account) {
        enforceIsNotBanned(account);
        _;
    }

    /**
     * @dev Revert if the address is on the OFAC sanctions list
     */
    modifier notSanctioned(address account) {
        enforceIsNotSanctioned(account);
        _;
    }

    /**
     * @dev reverts if the account is not the owner and doesn't have the required role.
     */
    function enforceOwnerOrRole(
        bytes32 role,
        address account
    ) public view virtual override {
        if (account != owner()) {
            _checkRole(role, account);
        }
    }

    /**
     * @dev reverts if the account is banned or on the OFAC sanctions list.
     */
    function enforceIsNotBanned(address account) public view virtual override {
        accessServer.enforceIsNotBannedForMe(account);
    }

    /**
     * @dev Revert if the address is on the OFAC sanctions list
     */
    function enforceIsNotSanctioned(
        address account
    ) public view virtual override {
        accessServer.enforceIsNotSanctioned(account);
    }

    /**
     * @dev returns true if the account is banned.
     */
    function isBanned(
        address account
    ) public view virtual override returns (bool) {
        return accessServer.isBannedForMe(account);
    }

    /**
     * @dev returns true if the account is on the OFAC sanctions list.
     */
    function isSanctioned(
        address account
    ) public view virtual override returns (bool) {
        return accessServer.isSanctioned(account);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override returns (bool) {
        return accessServer.hasRoleForMe(role, account);
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (role != ANY_ROLE) {
            accessServer.checkRoleForMe(role, account);
        }
    }

    /* ################################################################
     * Owner management
     * ##############################################################*/

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual override returns (address) {
        return accessServer.getMyOwner();
    }

    /**
     * Make another account the owner of this contract.
     * @param newOwner the new owner.
     *
     * Requirements:
     *
     * - Calling user MUST be owner.
     * - `newOwner` MUST NOT have the banned role.
     */
    function transferOwnership(address newOwner) public virtual {
        address oldOwner = owner();
        accessServer.setMyOwner(_msgSender(), newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /* ################################################################
     * Role Administration
     * ##############################################################*/

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(
        bytes32 role
    ) public view virtual override returns (bytes32) {
        return accessServer.getMyRoleAdmin(role);
    }

    /**
     * @dev Sets the admin role that controls a role.
     *
     * Requirements:
     * - caller MUST be the owner or have the admin role.
     */
    function setRoleAdmin(bytes32 role, bytes32 adminRole) public virtual {
        accessServer.setRoleAdmin(_msgSender(), role, adminRole);
    }

    /* ################################################################
     * Enumerating role members
     * ##############################################################*/

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(
        bytes32 role,
        uint256 index
    ) public view virtual override returns (address) {
        return accessServer.getMyRoleMember(role, index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(
        bytes32 role
    ) public view virtual override returns (uint256) {
        return accessServer.getMyRoleMemberCount(role);
    }

    /* ################################################################
     * Granting / Revoking / Renouncing roles
     * ##############################################################*/

    /**
     *  Requirements:
     *
     * - Calling user MUST have the admin role
     * - If `role` is banned, calling user MUST be the owner
     *   and `address` MUST NOT be the owner.
     * - If `role` is not banned, `account` MUST NOT be under sanctions.
     *
     * @inheritdoc IAccessControl
     */
    function grantRole(bytes32 role, address account) public virtual override {
        if (!hasRole(role, account)) {
            accessServer.grantRole(_msgSender(), role, account);
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * Take the role away from the account. This will throw an exception
     * if you try to take the admin role (0x00) away from the owner.
     *
     * Requirements:
     *
     * - Calling user has admin role.
     * - If `role` is admin, `address` MUST NOT be owner.
     * - if `role` is banned, calling user MUST be owner.
     *
     * @inheritdoc IAccessControl
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        if (hasRole(role, account)) {
            accessServer.revokeRole(_msgSender(), role, account);
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * Take a role away from yourself. This will throw an exception if you
     * are the contract owner and you are trying to renounce the admin role (0x00).
     *
     * Requirements:
     *
     * - if `role` is admin, calling user MUST NOT be owner.
     * - `account` is ignored.
     * - `role` MUST NOT be banned.
     *
     * @inheritdoc IAccessControl
     */
    function renounceRole(bytes32 role, address) public virtual override {
        renounceRole(role);
    }

    /**
     * Take a role away from yourself. This will throw an exception if you
     * are the contract owner and you are trying to renounce the admin role (0x00).
     *
     * Requirements:
     *
     * - if `role` is admin, calling user MUST NOT be owner.
     * - `role` MUST NOT be banned.
     */
    function renounceRole(bytes32 role) public virtual {
        accessServer.renounceRole(_msgSender(), role);
        emit RoleRevoked(role, _msgSender(), _msgSender());
        // if (hasRole(role, _msgSender())) {
        // }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
