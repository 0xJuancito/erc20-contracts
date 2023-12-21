import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

struct RoleData {
  mapping(address => bool) members;
  EnumerableSet.Bytes32Set keys;
  bytes32 adminRole;
}

struct AccessControlStorage {
  mapping(bytes32 => RoleData) roles;
}

interface IAccessControl {
  /// @notice Event emitted when the admin of a role changes
  /// @param role The role that changed
  /// @param previousAdminRole The previous admin role
  /// @param newAdminRole The new admin role
  event RoleAdminChanged(
    bytes32 indexed role,
    bytes32 indexed previousAdminRole,
    bytes32 indexed newAdminRole
  );

  /// @notice Event emitted when the role is granted to an account
  /// @param role The role that was granted
  /// @param account The account the role was granted to
  /// @param sender The message sender
  event RoleAccountGranted(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
  );

  /// @notice Event emitted when the role is revoked from an account
  /// @param role The role that was revoked
  /// @param account The account the role was revoked from
  /// @param sender The message sender
  event RoleAccountRevoked(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
  );

  /// @notice Event emitted when the role is granted to a DB key
  /// @param role The role that was granted
  /// @param key The DB key the role was granted to
  /// @param sender The message sender
  event RoleKeyGranted(
    bytes32 indexed role,
    bytes32 indexed key,
    address indexed sender
  );

  /// @notice Event emitted when the role is revoked from a DB key
  /// @param role The role that was revoked
  /// @param key The DB key the role was revoked from
  /// @param sender The message sender
  event RoleKeyRevoked(
    bytes32 indexed role,
    bytes32 indexed key,
    address indexed sender
  );

  /// @notice Grants the role to the account
  /// @param role The granted role
  /// @param account The account the role is granted to
  function grantRoleAccount(bytes32 role, address account) external;

  /// @notice Grants the role to the DB key
  /// @param role The granted role
  /// @param key The DB key the role is granted to
  function grantRoleKey(bytes32 role, bytes32 key) external;

  /// @notice Revokes the role from the account
  /// @param role The revoked role
  /// @param account The account the role is revoked from
  function revokeRoleAccount(bytes32 role, address account) external;

  /// @notice Revokes the role from the DB key
  /// @param role The revoked role
  /// @param key The DB key the role is revoked from
  function revokeRoleKey(bytes32 role, bytes32 key) external;

  /// @notice Removes the role from the message sender
  /// @param role The revoked role
  /// @param account The message sender
  function renounceRole(bytes32 role, address account) external;

  /// @notice Checks if the account has the role
  /// @param role The role the account is checked against
  /// @param account The
  /// @return If the account has the role
  function hasRole(bytes32 role, address account) external view returns (bool);

  /// @notice Gets the admin of the role
  /// @param role The role to get the admin for
  /// @return The admin of the role
  function getRoleAdmin(bytes32 role) external view returns (bytes32);
}
