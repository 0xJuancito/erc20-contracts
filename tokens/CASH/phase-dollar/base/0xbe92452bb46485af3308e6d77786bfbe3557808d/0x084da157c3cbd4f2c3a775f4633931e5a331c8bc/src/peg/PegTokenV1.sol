// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {PegTokenV1Storage} from "./PegTokenV1Storage.sol";
import {IPegToken} from "./IPegToken.sol";

contract PegTokenV1 is PegTokenV1Storage {
  /// @inheritdoc	IPegToken
  /// @custom:protected onlyRole(SNAPSHOT_ROLE)
  function snapshot() external override onlyRole(SNAPSHOT_ROLE) {
    _snapshot();
  }

  /// @inheritdoc	IPegToken
  /// @custom:protected onlyRole(MANAGER_ROLE)
  function mintManager(
    address to,
    uint256 amount
  ) external override onlyRole(MANAGER_ROLE) {
    _mint(to, amount);
  }

  /// @inheritdoc	IPegToken
  /// @custom:protected onlyRole(MANAGER_ROLE)
  function burnManager(
    address from,
    uint256 amount
  ) external override onlyRole(MANAGER_ROLE) {
    _burn(from, amount);
  }

  /// @inheritdoc	IPegToken
  /// @custom:protected onlyRole(MANAGER_ROLE)
  function transferManager(
    address from,
    address to,
    uint256 amount
  ) external override onlyRole(MANAGER_ROLE) {
    _transfer(from, to, amount);
  }
}
