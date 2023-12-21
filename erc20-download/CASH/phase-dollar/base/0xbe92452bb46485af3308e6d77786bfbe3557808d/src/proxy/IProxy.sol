// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

/// @title Proxy Interface
/// @author 0xPhase
/// @dev Allows for functionality to be loaded from another contract while running in local storage space
interface IProxy {
  /// @dev Function to receive ETH
  receive() external payable;

  /// @dev Fallback function to catch proxy calls
  /// returns This function will return whatever the implementation call returns
  fallback() external payable;

  /// @dev Tells the address of the implementation where every call will be delegated.
  /// @param sig The signature of the call
  /// @return _implementation The address of the implementation to which it will be delegated
  function implementation(
    bytes4 sig
  ) external view returns (address _implementation);

  /// @dev ERC897
  /// @return _type whether it is a forwarding (1) or an upgradeable (2) proxy
  function proxyType() external pure returns (uint256 _type);
}
