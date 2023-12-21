// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/oft/v2/OFTV2.sol";

/// @title Gravita Debt Token
/// @notice This contract locks tokens on source, on outgoing send(), and unlocks tokens when receiving from other chains.
contract GravitaDebtToken is OFTV2 {
    constructor(address _layerZeroEndpoint) OFTV2("Gravita Debt Token", "GRAI", _layerZeroEndpoint) {}
}
