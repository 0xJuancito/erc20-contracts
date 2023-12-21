// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//     _   ____________________           __  __    ____  ____________
//    / | / / ____/_  __/ ____/___ ______/ /_/ /_  / __ \/ ____/_  __/
//   /  |/ / /_    / / / __/ / __ `/ ___/ __/ __ \/ / / / /_    / /
//  / /|  / __/   / / / /___/ /_/ / /  / /_/ / / / /_/ / __/   / /
// /_/ |_/_/     /_/ /_____/\__,_/_/   \__/_/ /_/\____/_/     /_/

import "../token/oft/v2/OFTV2.sol";

/// @title An OmnichainFungibleToken using the LayerZero OFT standard

contract NFTEarthOFT is OFTV2 {
    constructor(string memory _name, string memory _symbol, uint8 _sharedDecimals, address _layerZeroEndpoint) OFTV2(_name, _symbol, _sharedDecimals, _layerZeroEndpoint) {
    }
}