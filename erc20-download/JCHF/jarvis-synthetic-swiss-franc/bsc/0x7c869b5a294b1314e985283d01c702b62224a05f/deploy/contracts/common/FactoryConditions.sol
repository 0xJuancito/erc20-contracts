// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {IStandardERC20} from '../base/interfaces/IStandardERC20.sol';
import {ISynthereumFinder} from '../core/interfaces/IFinder.sol';
import {
  ISynthereumCollateralWhitelist
} from '../core/interfaces/ICollateralWhitelist.sol';
import {
  ISynthereumIdentifierWhitelist
} from '../core/interfaces/IIdentifierWhitelist.sol';
import {SynthereumInterfaces} from '../core/Constants.sol';

/** @title Contract factory of self-minting derivatives
 */
contract FactoryConditions {
  /**
   * @notice Check if the sender is the deployer and if identifier and collateral are supported
   * @param synthereumFinder Synthereum finder
   * @param collateralToken Collateral token to check if it's in the whithelist
   * @param priceFeedIdentifier Identifier to check if it's in the whithelist
   */
  function checkDeploymentConditions(
    ISynthereumFinder synthereumFinder,
    IStandardERC20 collateralToken,
    bytes32 priceFeedIdentifier
  ) internal view {
    address deployer =
      synthereumFinder.getImplementationAddress(SynthereumInterfaces.Deployer);
    require(msg.sender == deployer, 'Sender must be Synthereum deployer');
    ISynthereumCollateralWhitelist collateralWhitelist =
      ISynthereumCollateralWhitelist(
        synthereumFinder.getImplementationAddress(
          SynthereumInterfaces.CollateralWhitelist
        )
      );
    require(
      collateralWhitelist.isOnWhitelist(address(collateralToken)),
      'Collateral not supported'
    );
    ISynthereumIdentifierWhitelist identifierWhitelist =
      ISynthereumIdentifierWhitelist(
        synthereumFinder.getImplementationAddress(
          SynthereumInterfaces.IdentifierWhitelist
        )
      );
    require(
      identifierWhitelist.isOnWhitelist(priceFeedIdentifier),
      'Identifier not supported'
    );
  }
}
