// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {pCNFI} from "../pCNFI.sol";

library pCNFIFactoryLib {
    bytes32 constant PCNFI_SALT = keccak256("connect-pcnfi");

    function getSalt() external pure returns (bytes32 result) {
        result = PCNFI_SALT;
    }

    function getBytecode() external pure returns (bytes memory result) {
        result = type(pCNFI).creationCode;
    }
}
