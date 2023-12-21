// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/extension/ProxyOFT.sol";

contract DAIProxyOFTV2 is ProxyOFT {
    constructor(address _token, address _layerZeroEndpoint) ProxyOFT(_token, _layerZeroEndpoint){}
}