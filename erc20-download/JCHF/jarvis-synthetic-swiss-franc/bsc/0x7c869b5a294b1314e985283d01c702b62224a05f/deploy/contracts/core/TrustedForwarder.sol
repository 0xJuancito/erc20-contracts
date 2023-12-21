// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ISynthereumTrustedForwarder} from './interfaces/ITrustedForwarder.sol';
import {Address} from '../../@openzeppelin/contracts/utils/Address.sol';
import {
  MinimalForwarder
} from '../../@openzeppelin/contracts/metatx/MinimalForwarder.sol';

contract SynthereumTrustedForwarder is
  ISynthereumTrustedForwarder,
  MinimalForwarder
{
  /**
   * @notice Check if the execute function reverts or not
   */
  function safeExecute(ForwardRequest calldata req, bytes calldata signature)
    public
    payable
    override
    returns (bytes memory)
  {
    (bool success, bytes memory returndata) = execute(req, signature);
    return
      Address.verifyCallResult(
        success,
        returndata,
        'Error in the TrustedForwarder call'
      );
  }
}
