// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RoleAccess is AccessControlEnumerable {
  // role definition
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");

  // struct
  struct Role {
    bytes32 role;
    string describe;
  }

  // modifier
  modifier onlyAdmin() {
    require(hasRole(ADMIN_ROLE, _msgSender()), "Caller is not a admin");
    _;
  }

  modifier onlyMinter() {
    require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
    _;
  }

  modifier onlyBurner() {
    require(hasRole(BURNER_ROLE, _msgSender()), "Caller is not a burner");
    _;
  }

  modifier onlyBlacklister() {
    require(
      hasRole(BLACKLISTER_ROLE, _msgSender()),
      "Caller is not a blacklister"
    );
    _;
  }

  function getRoles() public pure returns (Role[] memory) {
    Role[] memory result = new Role[](4);
    result[1] = Role(ADMIN_ROLE, "admin for the contract");
    result[2] = Role(MINTER_ROLE, "minter can mint new coins");
    result[3] = Role(BURNER_ROLE, "burner can burn coins");
    result[4] = Role(BLACKLISTER_ROLE, "blacklister can update blacklist");
    return result;
  }

  function addRoleMember(bytes32 role, address member)
    external
    onlyAdmin
    returns (bool)
  {
    grantRole(role, member);
    return true;
  }

  function removeRoleMember(bytes32 role, address member)
    external
    onlyAdmin
    returns (bool)
  {
    if (hasRole(role, member)) {
      revokeRole(role, member);
    }
    return true;
  }

  function getRoleMembers(bytes32 role)
    external
    view
    returns (address[] memory)
  {
    uint256 count = getRoleMemberCount(role);
    address[] memory members_ = new address[](count);
    for (uint256 index = 0; index < count; index++) {
      members_[index] = getRoleMember(role, index);
    }
    return members_;
  }

  // A few helper functions:

  // assign minter role to another EOA or smart contract
  function grantMinter(address minter) external onlyAdmin returns (bool) {
    grantRole(MINTER_ROLE, minter);
    return true;
  }

  // revoke minter role to another EOA or smart contract
  function revokeMinter(address minter) external onlyAdmin returns (bool) {
    revokeRole(MINTER_ROLE, minter);
    return true;
  }

  // assign burner role to another EOA or smart contract
  function grantBurner(address burner) external onlyAdmin returns (bool) {
    grantRole(BURNER_ROLE, burner);
    return true;
  }

  // revoke burner role to another EOA or smart contract
  function revokeBurner(address burner) external onlyAdmin returns (bool) {
    revokeRole(BURNER_ROLE, burner);
    return true;
  }

  // assign blacklister role to another EOA or smart contract
  function grantBlacklister(address blacklister)
    external
    onlyAdmin
    returns (bool)
  {
    grantRole(BLACKLISTER_ROLE, blacklister);
    return true;
  }

  // revoke blacklister role to another EOA or smart contract
  function revokeBlacklister(address blacklister)
    external
    onlyAdmin
    returns (bool)
  {
    revokeRole(BLACKLISTER_ROLE, blacklister);
    return true;
  }
}
