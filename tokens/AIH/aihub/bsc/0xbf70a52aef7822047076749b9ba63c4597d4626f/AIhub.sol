// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract AIhub is ERC20 {
    constructor() ERC20("AIhub", "AIH") {
        _mint(msg.sender, 100_000_000 * (10 ** uint256(decimals())));
    }
}