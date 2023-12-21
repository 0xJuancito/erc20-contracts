// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  EnumerableSet
} from '../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title Register and track all the pools deployed
 */
contract PoolRegistryMock {
  using EnumerableSet for EnumerableSet.AddressSet;

  //----------------------------------------
  // Storage
  //----------------------------------------

  mapping(string => mapping(IERC20 => mapping(uint8 => EnumerableSet.AddressSet)))
    private symbolToElements;

  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Allow the deployer to register an element
   * @param syntheticTokenSymbol Symbol of the syntheticToken
   * @param collateralToken Collateral ERC20 token of the element deployed
   * @param version Version of the element deployed
   * @param element Address of the element deployed
   */
  function register(
    string calldata syntheticTokenSymbol,
    IERC20 collateralToken,
    uint8 version,
    address element
  ) external {
    symbolToElements[syntheticTokenSymbol][collateralToken][version].add(
      element
    );
  }

  /**
   * @notice Returns if a particular element exists or not
   * @param syntheticTokenSymbol Synthetic token symbol of the element
   * @param collateralToken ERC20 contract of collateral currency
   * @param version Version of the element
   * @param element Contract of the element to check
   * @return isElementDeployed Returns true if a particular element exists, otherwise false
   */
  function isDeployed(
    string calldata syntheticTokenSymbol,
    IERC20 collateralToken,
    uint8 version,
    address element
  ) external view returns (bool isElementDeployed) {
    isElementDeployed = symbolToElements[syntheticTokenSymbol][collateralToken][
      version
    ]
      .contains(element);
  }
}
