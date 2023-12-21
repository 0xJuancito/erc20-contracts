// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

/// @title A LayerZero OmnichainFungibleToken example
contract ExampleOFTV2 is OFTV2 {
    constructor(string memory _name, string memory _symbol, uint8 _sharedDecimals, address _layerZeroEndpoint) OFTV2(_name, _symbol, _sharedDecimals, _layerZeroEndpoint) {
        // mint 1M to deployer
        _mint(_msgSender(), 1_000_000 * 10**18);
    }
}
