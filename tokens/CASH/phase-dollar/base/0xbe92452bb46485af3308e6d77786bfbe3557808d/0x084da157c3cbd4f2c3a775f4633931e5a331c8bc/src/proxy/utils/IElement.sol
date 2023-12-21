// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {IDB} from "../../db/IDB.sol";

struct ElementStorage {
  IDB db;
}

interface IElement {
  /// @notice Gets the DB contract
  /// @return The DB contract
  function db() external view returns (IDB);
}
