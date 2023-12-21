// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract RevertConstantsLib {
    bytes4 constant REVERT_MAGIC = 0x08c379a0;
    bytes4 constant REVERT_MASK = 0xffffffff;
}
