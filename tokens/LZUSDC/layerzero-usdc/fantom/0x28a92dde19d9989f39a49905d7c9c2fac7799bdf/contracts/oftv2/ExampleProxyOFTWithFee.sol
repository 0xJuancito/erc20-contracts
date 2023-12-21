// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/ProxyOFTV2.sol";

contract ExampleProxyOFTWithFee is ProxyOFTV2 {
    constructor(address _token, uint8 _sharedDecimals, address _layerZeroEndpoint) ProxyOFTV2(_token, _sharedDecimals, _layerZeroEndpoint){}
}