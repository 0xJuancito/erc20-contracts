// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library CallLib {
  /// @notice Transfers the amount to the target address
  /// @param target The target address
  /// @param amount The amount to transfer
  function transferTo(address target, uint256 amount) internal {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = payable(target).call{value: amount}("");

    require(success, "CallLib: Unsuccessful transfer");
  }

  /// @notice Calls an external function without value
  /// @param target The target contract
  /// @param data The calldata
  /// @return The result of the call
  function callFunc(
    address target,
    bytes memory data
  ) internal returns (bytes memory) {
    return callFunc(target, data, 0);
  }

  /// @notice Calls an external function with value
  /// @param target The target contract
  /// @param data The calldata
  /// @param value The value sent with the call
  /// @return The result of the call
  function callFunc(
    address target,
    bytes memory data,
    uint256 value
  ) internal returns (bytes memory) {
    require(
      address(this).balance >= value,
      "CallLib: insufficient balance for call"
    );

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.call{value: value}(data);

    return verifyCallResult(success, returndata, target, "call");
  }

  /// @notice Calls an external function in current storage
  /// @param target The target contract
  /// @param data The calldata
  /// @return The result of the call
  function delegateCallFunc(
    address target,
    bytes memory data
  ) internal returns (bytes memory) {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.delegatecall(data);

    return verifyCallResult(success, returndata, target, "delegateCall");
  }

  /// @notice Calls an external function
  /// @param target The target contract
  /// @param data The calldata
  /// @return The result of the call
  function viewFunc(
    address target,
    bytes memory data
  ) internal view returns (bytes memory) {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.staticcall(data);

    return verifyCallResult(success, returndata, target, "view");
  }

  /// @notice Verifies if a contract call succeeded
  /// @param success If the call itself succeeded
  /// @param result The result of the call
  /// @param target The called contract
  /// @param method The method type, call or delegateCall
  /// @return The result of the call
  function verifyCallResult(
    bool success,
    bytes memory result,
    address target,
    string memory method
  ) internal view returns (bytes memory) {
    if (success) {
      if (result.length == 0) {
        // only check isContract if the call was successful and the return data is empty
        // otherwise we already know that it was a contract
        require(Address.isContract(target), "CallLib: call to non-contract");
      }

      return result;
    } else {
      reverts(
        result,
        string.concat(
          "CallLib: Function ",
          method,
          " reverted silently for ",
          Strings.toHexString(target)
        )
      );
    }
  }

  /// @notice Reverts on wrong result
  /// @param result The byte result of the call
  /// @param message The default revert message
  function reverts(bytes memory result, string memory message) internal pure {
    // Look for revert reason and bubble it up if present
    if (result.length > 0) {
      // The easiest way to bubble the revert reason is using memory via assembly
      // solhint-disable-next-line no-inline-assembly
      assembly {
        let result_size := mload(result)
        revert(add(32, result), result_size)
      }
    } else {
      revert(message);
    }
  }
}
