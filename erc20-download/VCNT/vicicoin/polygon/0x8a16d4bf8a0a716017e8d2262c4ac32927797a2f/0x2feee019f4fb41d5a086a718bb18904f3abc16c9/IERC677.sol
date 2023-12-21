// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "IERC20Metadata.sol";

/**
 * @title IERC677 interface
 * @notice ERC677 extends ERC20 by adding the transfer and call function.
 */
interface IERC677 is IERC20Metadata {

    /**
     * @notice transfers `value` to `to` and calls `onTokenTransfer()`.
     * @param to the ERC677 Receiver
     * @param value the amount to transfer
     * @param data the abi encoded call data
     * 
     * Requirements:
     * - `to` MUST implement ERC677ReceiverInterface.
     * - `value` MUST be sufficient to cover the receiving contract's fee.
     * - `data` MUST be the types expected by the receiving contract.
     * - caller MUST be a contract that implements the callback function 
     *     required by the receiving contract.
     * - this contract must represent a token that is accepted by the receiving
     *     contract.
     */
    function transferAndCall(
        address to,
        uint256 value,
        bytes memory data
    ) external returns (bool success);
}
