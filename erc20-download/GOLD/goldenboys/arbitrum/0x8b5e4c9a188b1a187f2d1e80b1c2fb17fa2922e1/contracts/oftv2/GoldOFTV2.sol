// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

// Welcome to GoldenBoys Club
// Own it, make Yourself a GoldenBoy!
// Its Time to Shine

/// @title Gold OFTV2
contract GoldOFTV2 is OFTV2 {
    constructor(string memory _name, string memory _symbol, uint8 _sharedDecimals, address _layerZeroEndpoint) OFTV2(_name, _symbol, _sharedDecimals, _layerZeroEndpoint) {}
}
