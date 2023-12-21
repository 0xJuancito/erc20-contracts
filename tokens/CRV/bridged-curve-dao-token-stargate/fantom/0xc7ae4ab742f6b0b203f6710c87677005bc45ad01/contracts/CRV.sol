// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

/// @title A LayerZero OmnichainFungibleToken example
contract CRV is OFTV2 {
    constructor(address _layerZeroEndpoint) OFTV2("Curve DAO Token", "CRV", 6, _layerZeroEndpoint) {}
}
