// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

import {ProxyInitializable} from "./ProxyInitializable.sol";

abstract contract ProxyOwnable is ProxyInitializable {
  using StorageSlot for bytes32;

  bytes32 internal constant _OWNER_SLOT =
    bytes32(uint256(keccak256("proxy.ownable.owner")) - 1);

  /// @notice Event emitted when the ownership is transferred
  /// @param previousOwner The previous owner address
  /// @param newOwner The new owner address
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(
      msg.sender != address(0),
      "ProxyOwnable: Cannot be called by zero address"
    );

    require(owner() == msg.sender, "ProxyOwnable: Caller is not the owner");

    _;
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  /// @custom:protected onlyOwner
  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  /// @custom:protected onlyOwner
  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(
      newOwner != address(0),
      "ProxyOwnable: New owner is the zero address"
    );

    _transferOwnership(newOwner);
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view virtual returns (address) {
    return _OWNER_SLOT.getAddressSlot().value;
  }

  /**
   * @dev Initializes the contract setting the firstOwner as the initial owner.
   */
  function _initializeOwnership(
    address firstOwner
  ) internal initialize("owner") {
    _transferOwnership(firstOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = owner();
    _OWNER_SLOT.getAddressSlot().value = newOwner;

    emit OwnershipTransferred(oldOwner, newOwner);
  }
}
