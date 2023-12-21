// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/ProxyOFTV2.sol";
// Welcome to GoldenBoys Club
// Own it, make Yourself a GoldenBoy!
// Its Time to Shine

/// @title Gold Proxy OFTV2
contract GoldProxyOFTV2 is ProxyOFTV2 {
    constructor(address _token, uint8 _sharedDecimals, address _layerZeroEndpoint) ProxyOFTV2(_token, _sharedDecimals, _layerZeroEndpoint){}
}
