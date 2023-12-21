// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

/// @custom:security-contact security@bitmarkets.com
interface IBITMarketsToken {
  /**
   * @dev Takes snapshot of state and can return to it
   */
  function snapshot() external;
}
