// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface ILidoStaking {

  /// @notice Stake the amount of the account
  /// @param _account the address of account.
  /// @param _balance the balance of account.
  function stake(address _account, uint256 _balance) external;

  /// @notice View if the account is blacklisted
  /// @param _account the address of account.
  function blackListAccounts(address _account) external returns (bool); 
}