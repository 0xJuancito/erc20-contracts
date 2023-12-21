// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

contract WETH is OFT {
    constructor(address _layerZeroEndpoint) OFT("Wrapped Ether", "WETH", _layerZeroEndpoint) {}
}
