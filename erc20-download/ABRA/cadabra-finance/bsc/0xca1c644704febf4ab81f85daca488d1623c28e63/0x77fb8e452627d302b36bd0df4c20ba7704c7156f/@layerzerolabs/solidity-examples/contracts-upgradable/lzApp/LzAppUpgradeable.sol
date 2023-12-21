// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ILayerZeroReceiverUpgradeable.sol";
import "../interfaces/ILayerZeroUserApplicationConfigUpgradeable.sol";
import "../interfaces/ILayerZeroEndpointUpgradeable.sol";
import "../../util/BytesLib.sol";
import "./ILzAppUpgradeable.sol";

/*
 * a generic LzReceiver implementation
 */
abstract contract LzAppUpgradeable is Initializable, OwnableUpgradeable, ILzAppUpgradeable {
    using BytesLib for bytes;

    /// @custom:storage-location erc7201:lze.storage.LzApp
    struct LzAppStorage {
        ILayerZeroEndpointUpgradeable lzEndpoint;
        mapping(uint16 => bytes) trustedRemoteLookup;
        mapping(uint16 => mapping(uint16 => uint)) minDstGasLookup;
        mapping(uint16 => uint) payloadSizeLimitLookup;
        address precrime;
    }

    // keccak256(abi.encode(uint256(keccak256("lze.storage.LzApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LzAppStorageLocation = 0x0083f86f02ffa25b940610aea79a77dbd6f2ab52b5c09c032024c7a42a219900;

// ua can not send payload larger than this by default, but it can be changed by the ua owner
    uint constant public DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;

    function _getLzAppStorage() private pure returns (LzAppStorage storage $) {
        assembly {
            $.slot := LzAppStorageLocation
        }
    }

    function __LzAppUpgradeable_init(address _endpoint) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __LzAppUpgradeable_init_unchained(_endpoint);
    }

    function __LzAppUpgradeable_init_unchained(address _endpoint) internal onlyInitializing {
        LzAppStorage storage $ = _getLzAppStorage();
        $.lzEndpoint = ILayerZeroEndpointUpgradeable(_endpoint);
    }

    //---------------------------original public members --------------------------------------

    function lzEndpoint() public override view returns (ILayerZeroEndpointUpgradeable) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.lzEndpoint;
    }

    function trustedRemoteLookup(uint16 chainId) public override view returns (bytes memory) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.trustedRemoteLookup[chainId];
    }

    function minDstGasLookup(uint16 chainId, uint16 packetType) public override view returns (uint) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.minDstGasLookup[chainId][packetType];
    }

    function payloadSizeLimitLookup(uint16 chainId) public override view returns (uint) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.payloadSizeLimitLookup[chainId];
    }

    function precrime() public override view returns (address) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.precrime;
    }


    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public virtual override {
        LzAppStorage storage $ = _getLzAppStorage();
        // lzReceive must be called by the endpoint for security
        require(_msgSender() == address($.lzEndpoint), "LzApp: invalid endpoint caller");

        bytes memory trustedRemote = $.trustedRemoteLookup[_srcChainId];
        // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
        require(_srcAddress.length == trustedRemote.length && trustedRemote.length > 0 && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: invalid source sending contract");

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    // abstract function - the default behaviour of LayerZero is blocking. See: NonblockingLzApp if you dont need to enforce ordered messaging
    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal virtual {
        LzAppStorage storage $ = _getLzAppStorage();
        bytes memory trustedRemote = trustedRemoteLookup(_dstChainId);
        require(trustedRemote.length != 0, "LzApp: destination chain is not a trusted source");
        _checkPayloadSize(_dstChainId, _payload.length);
        $.lzEndpoint.send{value: _nativeFee}(_dstChainId, trustedRemote, _payload, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    function _checkGasLimit(uint16 _dstChainId, uint16 _type, bytes memory _adapterParams, uint _extraGas) internal view virtual {
        uint providedGasLimit = _getGasLimit(_adapterParams);
        LzAppStorage storage $ = _getLzAppStorage();
        uint minGasLimit = $.minDstGasLookup[_dstChainId][_type] + _extraGas;
        require(minGasLimit > 0, "LzApp: minGasLimit not set");
        require(providedGasLimit >= minGasLimit, "LzApp: gas limit is too low");
    }

    function _getGasLimit(bytes memory _adapterParams) internal pure virtual returns (uint gasLimit) {
        require(_adapterParams.length >= 34, "LzApp: invalid adapterParams");
        assembly {
            gasLimit := mload(add(_adapterParams, 34))
        }
    }

    function _checkPayloadSize(uint16 _dstChainId, uint _payloadSize) internal view virtual {
        LzAppStorage storage $ = _getLzAppStorage();
        uint payloadSizeLimit = $.payloadSizeLimitLookup[_dstChainId];
        if (payloadSizeLimit == 0) { // use default if not set
            payloadSizeLimit = DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(_payloadSize <= payloadSizeLimit, "LzApp: payload size is too large");
    }

    //---------------------------UserApplication config----------------------------------------
    function getConfig(uint16 _version, uint16 _chainId, address, uint _configType) external view returns (bytes memory) {
        LzAppStorage storage $ = _getLzAppStorage();
        return $.lzEndpoint.getConfig(_version, _chainId, address(this), _configType);
    }

    // generic config for LayerZero user Application
    function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.lzEndpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.lzEndpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.lzEndpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    // _path = abi.encodePacked(remoteAddress, localAddress)
    // this function set the trusted path for the cross-chain communication
    function setTrustedRemote(uint16 _srcChainId, bytes calldata _path) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.trustedRemoteLookup[_srcChainId] = _path;
        emit SetTrustedRemote(_srcChainId, _path);
    }

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.trustedRemoteLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
        emit SetTrustedRemoteAddress(_remoteChainId, _remoteAddress);
    }

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view override returns (bytes memory) {
        LzAppStorage storage $ = _getLzAppStorage();
        bytes memory path = $.trustedRemoteLookup[_remoteChainId];
        require(path.length != 0, "LzApp: no trusted path record");
        return path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
    }

    function setPrecrime(address _precrime) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.precrime = _precrime;
        emit SetPrecrime(_precrime);
    }

    function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint _minGas) external override onlyOwner {
        require(_minGas > 0, "LzApp: invalid minGas");
        LzAppStorage storage $ = _getLzAppStorage();
        $.minDstGasLookup[_dstChainId][_packetType] = _minGas;
        emit SetMinDstGas(_dstChainId, _packetType, _minGas);
    }

    // if the size is 0, it means default size limit
    function setPayloadSizeLimit(uint16 _dstChainId, uint _size) external override onlyOwner {
        LzAppStorage storage $ = _getLzAppStorage();
        $.payloadSizeLimitLookup[_dstChainId] = _size;
    }

    //--------------------------- VIEW FUNCTION ----------------------------------------
    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external view override returns (bool) {
        LzAppStorage storage $ = _getLzAppStorage();
        bytes memory trustedSource = $.trustedRemoteLookup[_srcChainId];
        return keccak256(trustedSource) == keccak256(_srcAddress);
    }

}
