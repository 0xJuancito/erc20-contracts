// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

import {ProxyOwnable} from "../utils/ProxyOwnable.sol";
import {BytesLib} from "../../lib/BytesLib.sol";
import {CallLib} from "../../lib/CallLib.sol";
import {IProxy} from "../IProxy.sol";
import {Proxy} from "../Proxy.sol";

/// @title Admin Upgradeable Proxy contract
/// @author 0xPhase
/// @dev Implementation of the Proxy contract in an owner upgradeable way
contract AdminUpgradeableProxy is ProxyOwnable, Proxy {
  using StorageSlot for bytes32;
  using BytesLib for bytes;

  bytes32 internal constant _IMPLEMENTATION_SLOT =
    bytes32(uint256(keccak256("proxy.implementation")) - 1);

  /// @dev Event emitted after upgrade of proxy
  /// @param _implementation New implementation for proxy
  event Upgraded(address indexed _implementation);

  /// @dev Initializes the upgradeable proxy with an initial implementation specified by `_target`.
  /// @param _owner Address of proxy owner
  /// @param _target Address of contract for proxy
  /// @param _initialCall Optional initial calldata
  constructor(address _owner, address _target, bytes memory _initialCall) {
    require(
      _owner != address(0),
      "AdminUpgradeableProxy: Owner cannot be 0 address"
    );

    require(
      _target != address(0),
      "AdminUpgradeableProxy: Target cannot be 0 address"
    );

    _setImplementation(_target);
    _initializeOwnership(_owner);

    if (_initialCall.length > 0) {
      CallLib.delegateCallFunc(_target, _initialCall);
    }
  }

  /// @dev Function to upgrade contract implementation
  /// @notice Only callable by the ecosystem owner
  /// @param _newImplementation Address of the new implementation
  /// @param _oldImplementationData Optional call data for old implementation before upgrade
  /// @param _newImplementationData Optional call data for new implementation after upgrade
  /// @custom:protected onlyOwner
  function upgradeTo(
    address _newImplementation,
    bytes calldata _oldImplementationData,
    bytes calldata _newImplementationData
  ) external onlyOwner {
    if (_oldImplementationData.length > 0) {
      CallLib.delegateCallFunc(implementation(msg.sig), _oldImplementationData);
    }

    _setImplementation(_newImplementation);

    if (_newImplementationData.length > 0) {
      CallLib.delegateCallFunc(implementation(msg.sig), _newImplementationData);
    }

    emit Upgraded(_newImplementation);
  }

  /// @inheritdoc IProxy
  function implementation(
    bytes4
  ) public view override returns (address _implementation) {
    _implementation = _IMPLEMENTATION_SLOT.getAddressSlot().value;
  }

  /// @inheritdoc IProxy
  function proxyType() public pure override returns (uint256 _type) {
    _type = 2;
  }

  /// @dev Function to upgrade contract implementation
  /// @param _newImplementation Address of the new implementation
  function _setImplementation(address _newImplementation) internal {
    _IMPLEMENTATION_SLOT.getAddressSlot().value = _newImplementation;
  }
}
