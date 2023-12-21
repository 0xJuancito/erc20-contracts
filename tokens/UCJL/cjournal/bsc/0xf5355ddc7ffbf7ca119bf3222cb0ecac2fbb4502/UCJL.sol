// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract UCJL is ERC20 {
    constructor() ERC20("UCJL", "UCJL") {
        _mint(msg.sender, 1_000_000_000 * (10**uint256(decimals())));
    }
}
