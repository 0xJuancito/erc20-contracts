// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;
import {
  MinimalForwarder
} from '../../../@openzeppelin/contracts/metatx/MinimalForwarder.sol';

interface ISynthereumTrustedForwarder {
  /**
   * @notice Check if the execute function reverts or not
   */
  function safeExecute(
    MinimalForwarder.ForwardRequest calldata req,
    bytes calldata signature
  ) external payable returns (bytes memory);
}
