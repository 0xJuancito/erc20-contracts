// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {IProxy} from "./IProxy.sol";

/// @title Proxy Contract
/// @author 0xPhase
/// @dev Allows for functionality to be loaded from another contract while running in local storage space
abstract contract Proxy is IProxy {
  // @inheritdoc IProxy
  // solhint-disable-next-line no-empty-blocks
  receive() external payable {}

  // @inheritdoc IProxy
  fallback() external payable {
    _fallback();
  }

  /// @dev Function to handle delegating the proxy call to target implementation
  /// returns This function will return whatever the implementation call returns
  function _fallback() internal {
    address _impl = IProxy(this).implementation(msg.sig);

    require(_impl != address(0), "Proxy: Implementation not set");

    // solhint-disable-next-line no-inline-assembly
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
