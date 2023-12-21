// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./ILzAppUpgradeable.sol";

interface INonblockingLzAppUpgradeable is ILzAppUpgradeable {

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);

    function failedMessages(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce) external view returns (bytes32);

    function nonblockingLzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;

    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external payable;
}
