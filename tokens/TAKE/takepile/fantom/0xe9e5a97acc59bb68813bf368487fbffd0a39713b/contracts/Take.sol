// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Take
/// @notice on creation mints max supply to contract creator
contract Take is ERC20 {
    uint256 public maxSupply = 10000000e18; // 10 million Take

    constructor() ERC20("Takepile Token", "TAKE") {
        _mint(msg.sender, maxSupply);
    }
}
