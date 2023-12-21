// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ILayerZeroReceiverUpgradeable.sol";
import "../interfaces/ILayerZeroUserApplicationConfigUpgradeable.sol";
import "../interfaces/ILayerZeroEndpointUpgradeable.sol";

interface ILzAppUpgradeable is ILayerZeroReceiverUpgradeable, ILayerZeroUserApplicationConfigUpgradeable {

    event SetPrecrime(address precrime);
    event SetTrustedRemote(uint16 _remoteChainId, bytes _path);
    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);
    event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint _minDstGas);

    //---------------------------original public members --------------------------------------


    function lzEndpoint() external view returns (ILayerZeroEndpointUpgradeable);
    function trustedRemoteLookup(uint16 chainId) external view returns (bytes memory);
    function minDstGasLookup(uint16 chainId, uint16 packetType) external view returns (uint);
    function payloadSizeLimitLookup(uint16 chainId) external view returns (uint);
    function precrime() external view returns (address);


    //---------------------------UserApplication config----------------------------------------
    function getConfig(uint16 _version, uint16 _chainId, address, uint _configType) external view returns (bytes memory);

    // _path = abi.encodePacked(remoteAddress, localAddress)
    // this function set the trusted path for the cross-chain communication
    function setTrustedRemote(uint16 _srcChainId, bytes calldata _path) external;

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external;

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory);

    function setPrecrime(address _precrime) external;

    function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint _minGas) external;

    // if the size is 0, it means default size limit
    function setPayloadSizeLimit(uint16 _dstChainId, uint _size) external;

    //--------------------------- VIEW FUNCTION ----------------------------------------
    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool);

}
