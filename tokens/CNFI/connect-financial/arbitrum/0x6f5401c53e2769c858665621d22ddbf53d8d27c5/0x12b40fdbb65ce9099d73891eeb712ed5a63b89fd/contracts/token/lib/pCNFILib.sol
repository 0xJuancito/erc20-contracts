// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { StringLib } from '../../util/StringLib.sol';
import { IStakingController } from '../../interfaces/IStakingController.sol';

library pCNFILib {
  using StringLib for *;

  function toSymbol(uint256 cycle) internal pure returns (string memory) {
    return abi.encodePacked('pCNFI', cycle.toString()).toString();
  }

  function toName(uint256 cycle) internal pure returns (string memory) {
    return abi.encodePacked('pCNFI Cycle ', cycle.toString()).toString();
  }
}
