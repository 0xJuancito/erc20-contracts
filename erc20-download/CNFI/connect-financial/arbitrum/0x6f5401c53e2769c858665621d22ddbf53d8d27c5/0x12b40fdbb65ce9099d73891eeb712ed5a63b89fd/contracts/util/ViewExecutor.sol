pragma experimental ABIEncoderV2;
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {RevertCaptureLib} from "./RevertCaptureLib.sol";

contract ViewExecutor {
    function encodeExecuteQuery(address viewLogic, bytes memory payload)
        internal
        pure
        returns (bytes memory retval)
    {
        retval = abi.encodeWithSignature(
            "_executeQuery(address,bytes)",
            viewLogic,
            payload
        );
    }

    function query(address viewLogic, bytes memory payload)
        public
        returns (bytes memory)
    {
        (bool success, bytes memory response) =
            address(this).call(encodeExecuteQuery(viewLogic, payload));
        if (success) revert(RevertCaptureLib.decodeError(response));
        return response;
    }

    function _bubbleReturnData(bytes memory result)
        internal
        pure
        returns (bytes memory)
    {
        assembly {
            return(add(result, 0x20), mload(result))
        }
    }

    function _bubbleRevertData(bytes memory result)
        internal
        pure
        returns (bytes memory)
    {
        assembly {
            revert(add(result, 0x20), mload(result))
        }
    }

    function _executeQuery(address delegateTo, bytes memory callData)
        public
        returns (bytes memory)
    {
        require(
            msg.sender == address(this),
            "unauthorized view layer delegation"
        );
        (bool success, bytes memory retval) = delegateTo.delegatecall(callData);

        if (success) _bubbleRevertData(retval);
        return _bubbleReturnData(retval);
    }
}
