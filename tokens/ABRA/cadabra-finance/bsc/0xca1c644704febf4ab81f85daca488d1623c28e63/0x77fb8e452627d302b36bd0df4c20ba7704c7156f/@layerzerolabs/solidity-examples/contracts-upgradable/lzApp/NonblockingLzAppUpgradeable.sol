// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./LzAppUpgradeable.sol";
import "../../util/ExcessivelySafeCall.sol";
import "./INonblockingLzAppUpgradeable.sol";

/*
 * the default LayerZero messaging behaviour is blocking, i.e. any failed message will block the channel
 * this abstract class try-catch all fail messages and store locally for future retry. hence, non-blocking
 * NOTE: if the srcAddress is not configured properly, it will still block the message pathway from (srcChainId, srcAddress)
 */
abstract contract NonblockingLzAppUpgradeable is Initializable, LzAppUpgradeable, INonblockingLzAppUpgradeable {
    using ExcessivelySafeCall for address;

    /// @custom:storage-location erc7201:lze.storage.NonblockingLzApp
    struct NonblockingLzAppStorage {
        mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) failedMessages;
    }

    // keccak256(abi.encode(uint256(keccak256("lze.storage.NonblockingLzApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NonblockingLzAppStorageLocation = 0x38ee0a08de9ec80bab29404d993fcc32865d8a382f5cdf7822adecf370d96300;

    function _getNonblockingLzAppStorage() private pure returns (NonblockingLzAppStorage storage $) {
        assembly {
            $.slot := NonblockingLzAppStorageLocation
        }
    }

    function __NonblockingLzAppUpgradeable_init(address _endpoint) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __LzAppUpgradeable_init_unchained(_endpoint);
    }

    function __NonblockingLzAppUpgradeable_init_unchained(address _endpoint) internal onlyInitializing {}

    function failedMessages(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce) public override view returns (bytes32) {
        NonblockingLzAppStorage storage $ = _getNonblockingLzAppStorage();
        return $.failedMessages[_srcChainId][_srcAddress][_nonce];
    }


    // overriding the virtual function in LzReceiver
    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual override {
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(gasleft(), 150, abi.encodeWithSelector(this.nonblockingLzReceive.selector, _srcChainId, _srcAddress, _nonce, _payload));
        // try-catch all errors/exceptions
        if (!success) {
            _storeFailedMessage(_srcChainId, _srcAddress, _nonce, _payload, reason);
        }
    }

    function _storeFailedMessage(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload, bytes memory _reason) internal virtual {
        NonblockingLzAppStorage storage $ = _getNonblockingLzAppStorage();
        $.failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
        emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, _reason);
    }

    function nonblockingLzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public override virtual {
        // only internal transaction
        require(_msgSender() == address(this), "NonblockingLzApp: caller must be LzApp");
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    //@notice override this function
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public payable override virtual {
        NonblockingLzAppStorage storage $ = _getNonblockingLzAppStorage();
        // assert there is message to retry
        bytes32 payloadHash = $.failedMessages[_srcChainId][_srcAddress][_nonce];
        require(payloadHash != bytes32(0), "NonblockingLzApp: no stored message");
        require(keccak256(_payload) == payloadHash, "NonblockingLzApp: invalid payload");
        // clear the stored message
        $.failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
        // execute the message. revert if it fails again
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);

        emit RetryMessageSuccess(_srcChainId, _srcAddress, _nonce, payloadHash);
    }

}
