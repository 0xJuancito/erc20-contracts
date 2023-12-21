// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

contract DAI is OFT {
    constructor(address _layerZeroEndpoint) OFT("Dai Stablecoin", "DAI", _layerZeroEndpoint) {}
}
