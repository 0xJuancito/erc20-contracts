// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {
  ISynthereumFactoryVersioning
} from '../../core/interfaces/IFactoryVersioning.sol';
import {
  SynthereumInterfaces,
  FactoryInterfaces
} from '../../core/Constants.sol';
import {MintableBurnableIERC20} from '../interfaces/MintableBurnableIERC20.sol';
import {Lockable} from '../../../@uma/core/contracts/common/implementation/Lockable.sol';

/**
 * @title Factory for creating new mintable and burnable tokens.
 */
abstract contract MintableBurnableTokenFactory is Lockable {
  //----------------------------------------
  // Storage
  //----------------------------------------

  ISynthereumFinder public synthereumFinder;

  //----------------------------------------
  // Modifiers
  //----------------------------------------

  modifier onlyDerivativeFactory() {
    ISynthereumFactoryVersioning factoryVersioning =
      ISynthereumFactoryVersioning(
        synthereumFinder.getImplementationAddress(
          SynthereumInterfaces.FactoryVersioning
        )
      );
    uint256 numberOfFactories =
      factoryVersioning.numberOfVerisonsOfFactory(
        FactoryInterfaces.DerivativeFactory
      );
    uint256 counter = 0;
    for (uint8 i = 0; counter < numberOfFactories; i++) {
      try
        factoryVersioning.getFactoryVersion(
          FactoryInterfaces.DerivativeFactory,
          i
        )
      returns (address factory) {
        if (msg.sender == factory) {
          _;
          break;
        } else {
          counter++;
        }
      } catch {}
    }
    if (numberOfFactories == counter) {
      revert('Sender must be a derivative factory');
    }
  }

  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Constructs SynthereumSyntheticTokenFactory contract
   * @param _synthereumFinder Synthereum finder contract
   */
  constructor(address _synthereumFinder) {
    synthereumFinder = ISynthereumFinder(_synthereumFinder);
  }

  /**
   * @notice Create a new token and return it to the caller.
   * @param tokenName used to describe the new token.
   * @param tokenSymbol short ticker abbreviation of the name. Ideally < 5 chars.
   * @param tokenDecimals used to define the precision used in the token's numerical representation.
   * @return newToken an instance of the newly created token interface.
   */
  function createToken(
    string memory tokenName,
    string memory tokenSymbol,
    uint8 tokenDecimals
  ) public virtual returns (MintableBurnableIERC20 newToken);

  /**
   * @notice Set admin rol to the token
   * @param token Token on which the adim role is set
   */
  function _setAdminRole(MintableBurnableIERC20 token) internal {
    token.addAdmin(msg.sender);
    token.renounceAdmin();
  }
}
