// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract Web3Frontier is ERC20 {
    constructor() ERC20("Web3Frontier", "W3F") {
        _mint(msg.sender, 100_000_000 * (10 ** uint256(decimals())));
    }
}
