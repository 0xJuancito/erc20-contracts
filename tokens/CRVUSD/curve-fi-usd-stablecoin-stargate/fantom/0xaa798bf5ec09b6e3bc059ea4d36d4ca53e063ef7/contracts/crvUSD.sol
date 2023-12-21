// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/fee/OFTWithFee.sol";

contract crvUSD is OFTWithFee {
    constructor(address _layerZeroEndpoint) OFTWithFee("Curve.Fi USD Stablecoin", "crvUSD", 6, _layerZeroEndpoint) {}
}
