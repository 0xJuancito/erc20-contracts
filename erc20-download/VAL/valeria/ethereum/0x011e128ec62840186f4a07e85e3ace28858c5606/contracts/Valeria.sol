// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./token/oft/OFT.sol";

/**
 __     __    _           _
 \ \   / /_ _| | ___ _ __(_) __ _
  \ \ / / _` | |/ _ \ '__| |/ _` |
   \ V / (_| | |  __/ |  | | (_| |
    \_/ \__,_|_|\___|_|  |_|\__,_|
*/

/// @title Valeria
/// @notice The ERC20 token (VAL) for Valeria games
/// @author @ValeriaStudios
contract Valeria is OFT {
    constructor(address _lzEndpoint) OFT("Valeria", "VAL", _lzEndpoint) {
        _mint(
            0xa00c7632d5B84010231A342E47e92107B538B0aE,
            400_000_000_000_000_000_000_000_000
        );
    }
}
