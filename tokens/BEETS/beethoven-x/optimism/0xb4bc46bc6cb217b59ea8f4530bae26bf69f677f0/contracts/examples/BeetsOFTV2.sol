// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/oft/v2/OFTV2.sol";

/// @title A LayerZero OmnichainFungibleToken for Beets on OP
contract BeetsOFTV2 is OFTV2 {
    constructor() OFTV2("BeethovenxToken", "BEETS", 6, 0x3c2269811836af69497E5F486A85D7316753cf62) { }
}
