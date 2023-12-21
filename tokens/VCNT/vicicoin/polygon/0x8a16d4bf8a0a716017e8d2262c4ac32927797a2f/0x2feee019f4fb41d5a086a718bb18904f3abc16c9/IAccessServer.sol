// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ChainalysisSanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}

/**
 * @title Access Server Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev Interface for the AccessServer.
 * @dev AccessServer client contracts SHOULD refer to the server contract via
 * this interface.
 */
interface IAccessServer {
    /**
     * @notice Emitted when a new administrator is added.
     */
    event AdminAddition(address indexed admin);

    /**
     * @notice Emitted when an administrator is removed.
     */
    event AdminRemoval(address indexed admin);

    /**
     * @notice Emitted when a resource is registered.
     */
    event ResourceRegistration(address indexed resource);

    /**
     * @notice Emitted when `newAdminRole` is set globally as ``role``'s admin
     * role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {GlobalRoleAdminChanged} not being emitted signaling this.
     */
    event GlobalRoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    /**
     * @notice Emitted when `account` is granted `role` globally.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event GlobalRoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @notice Emitted when `account` is revoked `role` globally.
     * @notice `account` will still have `role` where it was granted
     * specifically for any resources
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event GlobalRoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /* ################################################################
     * Modifiers / Rule Enforcement
     * ##############################################################*/

    /**
     * @dev Throws if the account is not the resource's owner.
     */
    function enforceIsOwner(address resource, address account) external view;

    /**
     * @dev Throws if the account is not the calling resource's owner.
     */
    function enforceIsMyOwner(address account) external view;

    /**
     * @dev Reverts if the account is not the resource owner or doesn't have
     * the moderator role for the resource.
     */
    function enforceIsModerator(address resource, address account)
        external
        view;

    /**
     * @dev Reverts if the account is not the resource owner or doesn't have
     * the moderator role for the calling resource.
     */
    function enforceIsMyModerator(address account) external view;

    /**
     * @dev Reverts if the account is under OFAC sanctions or is banned for the
     * resource
     */
    function enforceIsNotBanned(address resource, address account)
        external
        view;

    /**
     * @dev Reverts if the account is under OFAC sanctions or is banned for the
     * calling resource
     */
    function enforceIsNotBannedForMe(address account) external view;

    /**
     * @dev Reverts the account is on the OFAC sanctions list.
     */
    function enforceIsNotSanctioned(address account) external view;

    /**
     * @dev Reverts if the account is not the resource owner or doesn't have
     * the required role for the resource.
     */
    function enforceOwnerOrRole(
        address resource,
        bytes32 role,
        address account
    ) external view;

    /**
     * @dev Reverts if the account is not the resource owner or doesn't have
     * the required role for the calling resource.
     */
    function enforceOwnerOrRoleForMe(bytes32 role, address account)
        external
        view;

    /* ################################################################
     * Administration
     * ##############################################################*/

    /**
     * @dev Returns `true` if `admin` is an administrator of this AccessServer.
     */
    function isAdministrator(address admin) external view returns (bool);

    /**
     * @dev Adds `admin` as an administrator of this AccessServer.
     */
    function addAdministrator(address admin) external;

    /**
     * @dev Removes `admin` as an administrator of this AccessServer.
     */
    function removeAdministrator(address admin) external;

    /**
     * @dev Returns the number of administrators of this AccessServer.
     * @dev Use with `getAdminAt()` to enumerate.
     */
    function getAdminCount() external view returns (uint256);

    /**
     * @dev Returns the administrator at the index.
     * @dev Use with `getAdminCount()` to enumerate.
     */
    function getAdminAt(uint256 index) external view returns (address);

    /**
     * @dev Returns the list of administrators
     */
    function getAdmins() external view returns (address[] memory);

    /**
     * @dev returns the Chainalysis sanctions oracle.
     */
    function sanctionsList() external view returns (ChainalysisSanctionsList);

    /**
     * @dev Sets the Chainalysis sanctions oracle.
     * @dev setting this to the zero address disables sanctions compliance.
     * @dev Don't disable sanctions compliance unless there is some problem
     * with the sanctions oracle.
     */
    function setSanctionsList(ChainalysisSanctionsList _sanctionsList) external;

    /**
     * @dev Returns `true` if `account` is under OFAC sanctions.
     * @dev Returns `false` if sanctions compliance is disabled.
     */
    function isSanctioned(address account) external view returns (bool);

    /* ################################################################
     * Registration / Ownership
     * ##############################################################*/

    /**
     * @dev Registers the calling resource and sets the resource owner.
     * @dev Grants the default administrator role for the resource to the
     * resource owner.
     *
     * Requirements:
     * - caller SHOULD be a contract
     * - caller MUST NOT be already registered
     * - `owner` MUST NOT be the zero address
     * - `owner` MUST NOT be globally banned
     * - `owner` MUST NOT be under OFAC sanctions
     */
    function register(address owner) external;

    /**
     * @dev Returns `true` if `resource` is registered.
     */
    function isRegistered(address resource) external view returns (bool);

    /**
     * @dev Returns the owner of `resource`.
     */
    function getResourceOwner(address resource) external view returns (address);

    /**
     * @dev Returns the owner of the calling resource.
     */
    function getMyOwner() external view returns (address);

    /**
     * @dev Sets the owner for the calling resource.
     *
     * Requirements:
     * - caller MUST be a registered resource
     * - `operator` MUST be the current owner
     * - `newOwner` MUST NOT be the zero address
     * - `newOwner` MUST NOT be globally banned
     * - `newOwner` MUST NOT be banned by the calling resource
     * - `newOwner` MUST NOT be under OFAC sanctions
     * - `newOwner` MUST NOT be the current owner
     */
    function setMyOwner(address operator, address newOwner) external;

    /* ################################################################
     * Role Administration
     * ##############################################################*/

    /**
     * @dev Returns the admin role that controls `role` by default for all
     * resources. See {grantRole} and {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getGlobalRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Returns the admin role that controls `role` for a resource.
     * See {grantRole} and {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdminForResource(address resource, bytes32 role)
        external
        view
        returns (bytes32);

    /**
     * @dev Returns the admin role that controls `role` for the calling resource.
     * See {grantRole} and {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getMyRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Sets `adminRole` as ``role``'s admin role on as default all
     * resources.
     *
     * Requirements:
     * - caller MUST be an an administrator of this AccessServer
     */
    function setGlobalRoleAdmin(bytes32 role, bytes32 adminRole) external;

    /**
     * @dev Sets `adminRole` as ``role``'s admin role on the calling resource.
     * @dev There is no set roleAdminForResource vs setRoleAdminForMe.
     * @dev Resources must manage their own role admins or use the global
     * defaults.
     *
     * Requirements:
     * - caller MUST be a registered resource
     */
    function setRoleAdmin(
        address operator,
        bytes32 role,
        bytes32 adminRole
    ) external;

    /* ################################################################
     * Checking Role Membership
     * ##############################################################*/

    /**
     * @dev Returns `true` if `account` has been granted `role` as default for
     * all resources.
     */
    function hasGlobalRole(bytes32 role, address account)
        external
        view
        returns (bool);

    /**
     * @dev Returns `true` if `account` has been granted `role` globally or for
     * `resource`.
     */
    function hasRole(
        address resource,
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @dev Returns `true` if `account` has been granted `role` for `resource`.
     */
    function hasLocalRole(
        address resource,
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @dev Returns `true` if `account` has been granted `role` globally or for
     * the calling resource.
     */
    function hasRoleForMe(bytes32 role, address account)
        external
        view
        returns (bool);

    /**
     * @dev Returns `true` if account` is banned globally or from `resource`.
     */
    function isBanned(address resource, address account)
        external
        view
        returns (bool);

    /**
     * @dev Returns `true` if account` is banned globally or from the calling
     * resource.
     */
    function isBannedForMe(address account) external view returns (bool);

    /**
     * @dev Reverts if `account` has not been granted `role` globally or for
     * `resource`.
     */
    function checkRole(
        address resource,
        bytes32 role,
        address account
    ) external view;

    /**
     * @dev Reverts if `account` has not been granted `role` globally or for
     * the calling resource.
     */
    function checkRoleForMe(bytes32 role, address account) external view;

    /* ################################################################
     * Granting Roles
     * ##############################################################*/

    /**
     * @dev Grants `role` to `account` as default for all resources.
     * @dev Warning: This function can do silly things like applying a global
     * ban to a resource owner.
     *
     * Requirements:
     * - caller MUST be an an administrator of this AccessServer
     * - If `role` is not BANNED_ROLE_NAME, `account` MUST NOT be banned or
     *   under OFAC sanctions. Roles cannot be granted to such accounts.
     */
    function grantGlobalRole(bytes32 role, address account) external;

    /**
     * @dev Grants `role` to `account` for the calling resource as `operator`.
     * @dev There is no set grantRoleForResource vs grantRoleForMe.
     * @dev Resources must manage their own roles or use the global defaults.
     *
     * Requirements:
     * - caller MUST be a registered resource
     * - `operator` SHOULD be the account that called `grantRole()` on the
     *    calling resource.
     * - `operator` MUST be the resource owner or have the role admin role
     *    for `role` on the calling resource.
     * - If `role` is BANNED_ROLE_NAME, `account` MUST NOT be the resource
     *   owner. You can't ban the owner.
     * - If `role` is not BANNED_ROLE_NAME, `account` MUST NOT be banned or
     *   under OFAC sanctions. Roles cannot be granted to such accounts.
     */
    function grantRole(
        address operator,
        bytes32 role,
        address account
    ) external;

    /* ################################################################
     * Revoking / Renouncing Roles
     * ##############################################################*/

    /**
     * @dev Revokes `role` as default for all resources from `account`.
     *
     * Requirements:
     * - caller MUST be an an administrator of this AccessServer
     */
    function revokeGlobalRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account` for the calling resource as
     * `operator`.
     *
     * Requirements:
     * - caller MUST be a registered resource
     * - `operator` SHOULD be the account that called `revokeRole()` on the
     *    calling resource.
     * - `operator` MUST be the resource owner or have the role admin role
     *    for `role` on the calling resource.
     * - if `role` is DEFAULT_ADMIN_ROLE, `account` MUST NOT be the calling
     *   resource's owner. The admin role cannot be revoked from the owner.
     */
    function revokeRole(
        address operator,
        bytes32 role,
        address account
    ) external;

    /**
     * @dev Remove the default role for yourself. You will still have the role
     * for any resources where it was granted individually.
     *
     * Requirements:
     * - caller MUST have the role they are renouncing at the global level.
     * - `role` MUST NOT be BANNED_ROLE_NAME. You can't unban yourself.
     */
    function renounceRoleGlobally(bytes32 role) external;

    /**
     * @dev Renounces `role` for the calling resource as `operator`.
     *
     * Requirements:
     * - caller MUST be a registered resource
     * - `operator` SHOULD be the account that called `renounceRole()` on the
     *    calling resource.
     * - `operator` MUST have the role they are renouncing on the calling
     *   resource.
     * - if `role` is DEFAULT_ADMIN_ROLE, `operator` MUST NOT be the calling
     *   resource's owner. The owner cannot renounce the admin role.
     * - `role` MUST NOT be BANNED_ROLE_NAME. You can't unban yourself.
     */
    function renounceRole(address operator, bytes32 role) external;

    /* ################################################################
     * Enumerating Role Members
     * ##############################################################*/

    /**
     * @dev Returns the number of accounts that have `role` set at the global
     * level.
     * @dev Use with `getGlobalRoleMember()` to enumerate.
     */
    function getGlobalRoleMemberCount(bytes32 role) external view returns (uint256);

    /**
     * @dev Returns one of the accounts that have `role` set at the global
     * level.
     * @dev Use with `getGlobalRoleMemberCount()` to enumerate.
     *
     * Requirements:
     * `index` MUST be >= 0 and < `getGlobalRoleMemberCount(role)`
     */
    function getGlobalRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the list of accounts that have `role` set at the global
     * level.
     */
    function getGlobalRoleMembers(bytes32 role) external view returns (address[] memory);

    /**
     * @dev Returns the number of accounts that have `role` set globally or for 
     * `resource`.
     * @dev Use with `getRoleMember()` to enumerate.
     */
    function getRoleMemberCount(address resource, bytes32 role) external view returns (uint256);

    /**
     * @dev Returns one of the accounts that have `role` set globally or for 
     * `resource`. 
     * @dev If a role has global and local members, the global members 
     * will be returned first.
     * @dev If a user has the role globally and locally, the same user will be 
     * returned at two different indexes.
     * @dev If you only want locally assigned role members, start the index at
     * `getGlobalRoleMemberCount(role)`.
     * @dev Use with `getRoleMemberCount()` to enumerate.
     *
     * Requirements:
     * `index` MUST be >= 0 and < `getRoleMemberCount(role)`
     */
    function getRoleMember(
        address resource,
        bytes32 role,
        uint256 index
    ) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role` set globally or for 
     * the calling resource.
     * @dev Use with `getMyRoleMember()` to enumerate.
     */
    function getMyRoleMemberCount(bytes32 role) external view returns (uint256);

    /**
     * @dev Returns one of the accounts that have `role` set globally or for 
     * the calling resource.
     * @dev If a role has global and local members, the global members 
     * will be returned first.
     * @dev If a user has the role globally and locally, the same user will be 
     * returned at two different indexes.
     * @dev If you only want locally assigned role members, start the index at
     * `getGlobalRoleMemberCount(role)`.
     * @dev Use with `getMyRoleMemberCount()` to enumerate.
     *
     * Requirements:
     * `index` MUST be >= 0 and < `getMyRoleMemberCount(role)`
     */
    function getMyRoleMember(bytes32 role, uint256 index) external view returns (address);
}
