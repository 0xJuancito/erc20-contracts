// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

/// @title A LayerZero OmnichainFungibleToken example
contract ExampleOFT is OFT {
    constructor(string memory _name, string memory _symbol, address _layerZeroEndpoint) OFT(_name, _symbol, _layerZeroEndpoint) {
        // mint 1M to deployer
        _mint(_msgSender(), 1_000_000 * 10**18);
    }
}
