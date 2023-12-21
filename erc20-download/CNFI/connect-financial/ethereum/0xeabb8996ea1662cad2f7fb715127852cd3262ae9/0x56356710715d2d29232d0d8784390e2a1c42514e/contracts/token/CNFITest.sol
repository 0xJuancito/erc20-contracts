// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
import {ConnectTokenArb} from "./CNFIArb.sol";

contract ConnectTokenTest is ConnectTokenArb {
  function mint(address target, uint256 amount) public {
    _mint(target, amount);
  }

  function setStakingController(address sc) public virtual override {
    bytes32 _STAKING_CONTROLLER_SLOT = STAKING_CONTROLLER_SLOT;
    assembly {
      sstore(_STAKING_CONTROLLER_SLOT, sc)
    }
  }
}
