// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IAccessControl, AccessControlStorage, RoleData} from "./IAccessControl.sol";
import {Element} from "../proxy/utils/Element.sol";
import {IDB} from "../db/IDB.sol";

contract AccessControl is IAccessControl, ERC165, Element {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  bytes32 internal constant _ACCESS_CONTROL_STORAGE_SLOT =
    bytes32(uint256(keccak256("access.control.storage")) - 1);

  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

  /// @notice Checks if the message sender has the role
  /// @param role The role to check against
  modifier onlyRole(bytes32 role) {
    _checkRole(role);
    _;
  }

  /// @inheritdoc	IAccessControl
  /// @custom:protected onlyRole(getRoleAdmin(role))
  function grantRoleAccount(
    bytes32 role,
    address account
  ) public virtual override onlyRole(getRoleAdmin(role)) {
    _grantRoleAccount(role, account);
  }

  /// @inheritdoc	IAccessControl
  /// @custom:protected onlyRole(getRoleAdmin(role))
  function grantRoleKey(
    bytes32 role,
    bytes32 key
  ) public virtual override onlyRole(getRoleAdmin(role)) {
    _grantRoleKey(role, key);
  }

  /// @inheritdoc	IAccessControl
  /// @custom:protected onlyRole(getRoleAdmin(role))
  function revokeRoleAccount(
    bytes32 role,
    address account
  ) public virtual override onlyRole(getRoleAdmin(role)) {
    _revokeRoleAccount(role, account);
  }

  /// @inheritdoc	IAccessControl
  /// @custom:protected onlyRole(getRoleAdmin(role))
  function revokeRoleKey(
    bytes32 role,
    bytes32 key
  ) public virtual override onlyRole(getRoleAdmin(role)) {
    _revokeRoleKey(role, key);
  }

  /// @inheritdoc	IAccessControl
  function renounceRole(bytes32 role, address account) public virtual override {
    require(
      account == msg.sender,
      "AccessControl: can only renounce roles for self"
    );

    _revokeRoleAccount(role, account);
  }

  /// @inheritdoc	ERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override returns (bool) {
    return
      interfaceId == type(IAccessControl).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /// @inheritdoc	IAccessControl
  function hasRole(
    bytes32 role,
    address account
  ) public view virtual override returns (bool) {
    RoleData storage roleData = _acs().roles[role];

    if (roleData.members[account]) return true;

    bytes32 addr = bytes32(bytes20(account));
    uint256 length = roleData.keys.length();
    IDB db = db();

    for (uint256 i = 0; i < length; ) {
      if (db.hasPair(roleData.keys.at(i), addr)) return true;

      unchecked {
        i++;
      }
    }

    return false;
  }

  /// @inheritdoc	IAccessControl
  function getRoleAdmin(
    bytes32 role
  ) public view virtual override returns (bytes32) {
    return _acs().roles[role].adminRole;
  }

  /// @notice Sets up an account with a role
  /// @param role The role to give to the account
  /// @param account The receiver account
  function _setupRole(bytes32 role, address account) internal virtual {
    _grantRoleAccount(role, account);
  }

  /// @notice Sets the admin of the role
  /// @param role The role to set the admin for
  /// @param adminRole The admin role
  function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
    bytes32 previousAdminRole = getRoleAdmin(role);
    _acs().roles[role].adminRole = adminRole;
    emit RoleAdminChanged(role, previousAdminRole, adminRole);
  }

  /// @notice Grants the role to the account
  /// @param role The granted role
  /// @param account The account the role is granted to
  function _grantRoleAccount(bytes32 role, address account) internal virtual {
    RoleData storage roleData = _acs().roles[role];

    if (!roleData.members[account]) {
      roleData.members[account] = true;
      emit RoleAccountGranted(role, account, msg.sender);
    }
  }

  /// @notice Grants the role to the DB key
  /// @param role The granted role
  /// @param key The DB key the role is granted to
  function _grantRoleKey(bytes32 role, bytes32 key) internal virtual {
    if (_acs().roles[role].keys.add(key)) {
      emit RoleKeyGranted(role, key, msg.sender);
    }
  }

  /// @notice Revokes the role from the account
  /// @param role The revoked role
  /// @param account The account the role is revoked from
  function _revokeRoleAccount(bytes32 role, address account) internal virtual {
    RoleData storage roleData = _acs().roles[role];

    if (roleData.members[account]) {
      roleData.members[account] = false;
      emit RoleAccountRevoked(role, account, msg.sender);
    }
  }

  /// @notice Revokes the role from the DB key
  /// @param role The revoked role
  /// @param key The DB key the role is revoked from
  function _revokeRoleKey(bytes32 role, bytes32 key) internal virtual {
    if (_acs().roles[role].keys.remove(key)) {
      emit RoleKeyRevoked(role, key, msg.sender);
    }
  }

  /// @notice Checks if the message sender has the role
  /// @param role The role to check against
  function _checkRole(bytes32 role) internal view virtual {
    _checkRole(role, msg.sender);
  }

  /// @notice Checks if the account has the role
  /// @param role The role to check against
  /// @param account The account to check for
  function _checkRole(bytes32 role, address account) internal view virtual {
    if (hasRole(role, account) || hasRole(getRoleAdmin(role), account)) return;

    revert(
      string(
        abi.encodePacked(
          "AccessControl: account ",
          Strings.toHexString(uint160(account), 20),
          " is missing role ",
          Strings.toHexString(uint256(role), 32),
          " for AccessControl ",
          Strings.toHexString(uint160(address(this)), 20)
        )
      )
    );
  }

  /// @notice Returns the pointer to the access control storage
  /// @return s Access control storage pointer
  function _acs() internal pure returns (AccessControlStorage storage s) {
    bytes32 slot = _ACCESS_CONTROL_STORAGE_SLOT;

    // solhint-disable-next-line no-inline-assembly
    assembly {
      s.slot := slot
    }
  }
}
