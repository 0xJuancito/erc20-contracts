// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

interface ISystemClock {
  /// @notice Gets the time while updating it
  /// @return The current time
  function time() external returns (uint256);

  /// @notice Gets the time without updating it
  /// @return The current time
  function getTime() external view returns (uint256);

  /// @notice Gets the last updated time
  /// @return The last updated time
  function lastTime() external view returns (uint256);
}
