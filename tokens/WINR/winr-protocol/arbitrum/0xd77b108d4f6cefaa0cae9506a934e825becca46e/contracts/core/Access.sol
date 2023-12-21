// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract Access is AccessControlEnumerable {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(address _gov) {
    _grantRole(DEFAULT_ADMIN_ROLE, _gov);
  }

  modifier onlyGovernance() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "VM: Not governance");
    _;
  }
}
