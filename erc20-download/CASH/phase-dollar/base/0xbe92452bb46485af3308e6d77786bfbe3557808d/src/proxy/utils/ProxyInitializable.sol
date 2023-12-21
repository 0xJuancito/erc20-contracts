// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ProxyInitializable {
  using StorageSlot for bytes32;

  /// @notice Event emitted when a version is initalized
  /// @param version The initialized version
  event VersionInitialized(string indexed version);

  /// @notice Runs function if contract has been initialized
  /// @param version The version to initalize
  modifier initialize(string memory version) {
    StorageSlot.BooleanSlot storage disabledSlot = _disabledSlot()
      .getBooleanSlot();

    StorageSlot.BooleanSlot storage versionSlot = _versionSlot(version)
      .getBooleanSlot();

    if (!disabledSlot.value && !versionSlot.value) {
      _;

      emit VersionInitialized(version);
      versionSlot.value = true;
    }
  }

  /// @notice Internal function to disable all initializations
  function _disableInitialization() internal {
    StorageSlot.BooleanSlot storage disabledSlot = _disabledSlot()
      .getBooleanSlot();

    disabledSlot.value = true;
  }

  /// @notice Returns the slot for the disabled boolean
  /// @return The disabled boolean
  function _disabledSlot() internal pure returns (bytes32) {
    return bytes32(uint256(keccak256("proxy.initializable.disabled")) - 1);
  }

  /// @notice Returns the slot for the version initialized boolean
  /// @param version The version
  /// @return The version initialized boolean
  function _versionSlot(string memory version) internal pure returns (bytes32) {
    return
      bytes32(
        uint256(
          keccak256(
            bytes(string.concat("proxy.initializable.initialized.", version))
          )
        ) - 1
      );
  }
}
