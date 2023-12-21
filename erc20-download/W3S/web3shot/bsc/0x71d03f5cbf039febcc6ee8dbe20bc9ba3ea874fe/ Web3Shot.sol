// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract Web3Shot is ERC20 {
    constructor() ERC20("Web3Shot", "W3S") {
        _mint(msg.sender, 100_000_000 * (10**uint256(decimals())));
    }
}
