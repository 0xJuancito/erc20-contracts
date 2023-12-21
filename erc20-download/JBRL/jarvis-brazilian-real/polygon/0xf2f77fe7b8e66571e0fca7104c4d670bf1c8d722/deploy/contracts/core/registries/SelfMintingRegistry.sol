// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {SynthereumRegistry} from './Registry.sol';
import {ISynthereumFinder} from '../interfaces/IFinder.sol';

/**
 * @title Register and track all the self-minting derivatives deployed
 */
contract SelfMintingRegistry is SynthereumRegistry {
  /**
   * @notice Constructs the SelfMintingRegistry contract
   * @param _synthereumFinder Synthereum finder contract
   */
  constructor(ISynthereumFinder _synthereumFinder)
    SynthereumRegistry('SELF MINTING REGISTRY', _synthereumFinder)
  {}
}
