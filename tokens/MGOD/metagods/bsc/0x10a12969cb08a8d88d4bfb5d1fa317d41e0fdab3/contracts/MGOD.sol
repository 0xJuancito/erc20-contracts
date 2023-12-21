// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract MGOD is ERC20PresetFixedSupply {
    constructor()
        ERC20PresetFixedSupply(
            "MetaGods",
            "MGOD",
            5 * (10**8) * (10**18),
            msg.sender
        )
    {}
}