// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import { sCNFI } from "./sCNFI.sol";

library sCNFIFactoryLib {
  bytes32 constant _SALT = keccak256("StakingController:sCNFI");
  function SALT() internal pure returns (bytes32) {
    return _SALT;
  }
  function getBytecode() external pure returns (bytes memory bytecode) {
    bytecode = type(sCNFI).creationCode;
  }
}
    
