// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {
  ISynthereumIdentifierWhitelist
} from './interfaces/IIdentifierWhitelist.sol';
import {EnumerableBytesSet} from '../base/utils/EnumerableBytesSet.sol';
import {StringUtils} from '../base/utils/StringUtils.sol';
import {
  AccessControlEnumerable
} from '../../@openzeppelin/contracts/access/AccessControlEnumerable.sol';

/**
 * @title A contract to track a whitelist of identifiers.
 */
contract SynthereumIdentifierWhitelist is
  ISynthereumIdentifierWhitelist,
  AccessControlEnumerable
{
  using EnumerableBytesSet for EnumerableBytesSet.BytesSet;

  bytes32 private constant ADMIN_ROLE = 0x00;

  bytes32 public constant MAINTAINER_ROLE = keccak256('Maintainer');

  //Describe role structure
  struct Roles {
    address admin;
    address maintainer;
  }

  EnumerableBytesSet.BytesSet private identifiers;

  event AddedToWhitelist(bytes32 indexed addedIdentifier);
  event RemovedFromWhitelist(bytes32 indexed removedIdentifier);

  //----------------------------------------
  // Modifiers
  //----------------------------------------

  modifier onlyMaintainer() {
    require(
      hasRole(MAINTAINER_ROLE, msg.sender),
      'Sender must be the maintainer'
    );
    _;
  }

  /**
   * @notice Constructs the SynthereumIdentifierWhitelist contract
   * @param roles Admin and Maintainer roles
   */
  constructor(Roles memory roles) {
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
    _setupRole(DEFAULT_ADMIN_ROLE, roles.admin);
    _setupRole(MAINTAINER_ROLE, roles.maintainer);
  }

  /**
   * @notice Adds an identifier to the whitelist.
   * @param newIdentifier the new identifier to add.
   */
  function addToWhitelist(bytes32 newIdentifier)
    external
    override
    onlyMaintainer
  {
    require(identifiers.add(newIdentifier), 'Identifier already supported');
    emit AddedToWhitelist(newIdentifier);
  }

  /**
   * @notice Removes an identifier from the whitelist.
   * @param identifierToRemove The existing identifier to remove.
   */
  function removeFromWhitelist(bytes32 identifierToRemove)
    external
    override
    onlyMaintainer
  {
    require(identifiers.remove(identifierToRemove), 'Identifier not supported');
    emit RemovedFromWhitelist(identifierToRemove);
  }

  /**
   * @notice Checks whether an address is on the whitelist.
   * @param identifierToCheck The address to check.
   * @return True if `identifierToCheck` is on the whitelist, or False.
   */
  function isOnWhitelist(bytes32 identifierToCheck)
    external
    view
    override
    returns (bool)
  {
    return identifiers.contains(identifierToCheck);
  }

  /**
   * @notice Gets all identifiers that are currently included in the whitelist.
   * @return The list of identifiers on the whitelist.
   */
  function getWhitelist() external view override returns (bytes32[] memory) {
    uint256 numberOfElements = identifiers.length();
    bytes32[] memory activeIdentifiers = new bytes32[](numberOfElements);
    for (uint256 j = 0; j < numberOfElements; j++) {
      activeIdentifiers[j] = identifiers.at(j);
    }
    return activeIdentifiers;
  }
}
