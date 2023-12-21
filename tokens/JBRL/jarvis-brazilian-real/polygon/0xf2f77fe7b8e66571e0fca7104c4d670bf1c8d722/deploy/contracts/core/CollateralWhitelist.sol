// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {
  ISynthereumCollateralWhitelist
} from './interfaces/ICollateralWhitelist.sol';
import {
  EnumerableSet
} from '../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {
  AccessControlEnumerable
} from '../../@openzeppelin/contracts/access/AccessControlEnumerable.sol';

/**
 * @title A contract to track a whitelist of addresses.
 */
contract SynthereumCollateralWhitelist is
  ISynthereumCollateralWhitelist,
  AccessControlEnumerable
{
  using EnumerableSet for EnumerableSet.AddressSet;

  bytes32 private constant ADMIN_ROLE = 0x00;

  bytes32 public constant MAINTAINER_ROLE = keccak256('Maintainer');

  //Describe role structure
  struct Roles {
    address admin;
    address maintainer;
  }

  EnumerableSet.AddressSet private collaterals;

  event AddedToWhitelist(address indexed addedCollateral);
  event RemovedFromWhitelist(address indexed removedCollateral);

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
   * @notice Constructs the SynthereumCollateralWhitelist contract
   * @param roles Admin and Maintainer roles
   */
  constructor(Roles memory roles) {
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
    _setupRole(DEFAULT_ADMIN_ROLE, roles.admin);
    _setupRole(MAINTAINER_ROLE, roles.maintainer);
  }

  /**
   * @notice Adds an address to the whitelist.
   * @param newCollateral the new address to add.
   */
  function addToWhitelist(address newCollateral)
    external
    override
    onlyMaintainer
  {
    require(collaterals.add(newCollateral), 'Collateral already supported');
    emit AddedToWhitelist(newCollateral);
  }

  /**
   * @notice Removes an address from the whitelist.
   * @param collateralToRemove The existing address to remove.
   */
  function removeFromWhitelist(address collateralToRemove)
    external
    override
    onlyMaintainer
  {
    require(collaterals.remove(collateralToRemove), 'Collateral not supported');
    emit RemovedFromWhitelist(collateralToRemove);
  }

  /**
   * @notice Checks whether an address is on the whitelist.
   * @param collateralToCheck The address to check.
   * @return True if `collateralToCheck` is on the whitelist, or False.
   */
  function isOnWhitelist(address collateralToCheck)
    external
    view
    override
    returns (bool)
  {
    return collaterals.contains(collateralToCheck);
  }

  /**
   * @notice Gets all addresses that are currently included in the whitelist.
   * @return The list of addresses on the whitelist.
   */
  function getWhitelist() external view override returns (address[] memory) {
    uint256 numberOfElements = collaterals.length();
    address[] memory activeCollaterals = new address[](numberOfElements);
    for (uint256 j = 0; j < numberOfElements; j++) {
      activeCollaterals[j] = collaterals.at(j);
    }
    return activeCollaterals;
  }
}
