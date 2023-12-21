// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {IElement, ElementStorage} from "./IElement.sol";
import {IDB} from "../../db/IDB.sol";

abstract contract Element is IElement {
  bytes32 internal constant _ELEMENT_STORAGE_SLOT =
    bytes32(uint256(keccak256("element.proxy.storage")) - 1);

  /// @inheritdoc IElement
  function db() public view override returns (IDB) {
    return _es().db;
  }

  /// @notice Initializes the element contract
  /// @param db_ The protocol DB
  function _initializeElement(IDB db_) internal {
    require(address(db_) != address(0), "Element: DB cannot be 0 address");

    _es().db = db_;
  }

  /// @notice Returns the pointer to the element storage
  /// @return s Element storage pointer
  function _es() internal pure returns (ElementStorage storage s) {
    bytes32 slot = _ELEMENT_STORAGE_SLOT;

    // solhint-disable-next-line no-inline-assembly
    assembly {
      s.slot := slot
    }
  }
}
