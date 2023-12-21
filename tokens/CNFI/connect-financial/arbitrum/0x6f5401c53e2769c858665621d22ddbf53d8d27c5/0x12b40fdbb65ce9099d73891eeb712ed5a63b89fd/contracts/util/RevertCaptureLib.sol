// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {SliceLib} from "./SliceLib.sol";

library RevertCaptureLib {
    using SliceLib for *;
    uint32 constant REVERT_WITH_REASON_MAGIC = 0x08c379a0; // keccak256("Error(string)")

    function decodeError(bytes memory buffer)
        internal
        pure
        returns (string memory)
    {
        if (buffer.length == 0) return "captured empty revert buffer";
        if (
            uint32(uint256(bytes32(buffer.toSlice(0, 4).asWord()))) ==
            REVERT_WITH_REASON_MAGIC
        ) {
            bytes memory revertMessageEncoded = buffer.toSlice(4).copy();
            if (revertMessageEncoded.length == 0)
                return "captured empty revert message";
            string memory revertMessage =
                abi.decode(revertMessageEncoded, (string));
            return revertMessage;
        }
        return string(buffer);
    }
}
