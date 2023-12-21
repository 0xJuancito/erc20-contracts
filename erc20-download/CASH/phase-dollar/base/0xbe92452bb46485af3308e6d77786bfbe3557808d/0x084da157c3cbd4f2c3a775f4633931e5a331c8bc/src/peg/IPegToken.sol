// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

interface IPegToken {
  /// @notice Takes a snapshot of the current token state
  function snapshot() external;

  /// @notice Mints tokens for the manager
  /// @param to The address to mint tokens to
  /// @param amount The amount of tokens to mint
  function mintManager(address to, uint256 amount) external;

  /// @notice Burns tokens for the manager
  /// @param from The address to burn tokens from
  /// @param amount The amount of tokens to burn
  function burnManager(address from, uint256 amount) external;

  /// @notice Transfers tokens for the manager
  /// @param from The address to transfer the tokens from
  /// @param to The address to transfer the tokens to
  /// @param amount The amount of tokens to transfer
  function transferManager(address from, address to, uint256 amount) external;
}
