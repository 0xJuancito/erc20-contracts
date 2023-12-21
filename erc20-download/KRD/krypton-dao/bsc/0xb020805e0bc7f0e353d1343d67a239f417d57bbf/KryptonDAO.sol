// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract KryptonDAO is ERC20 {
    constructor() ERC20("Krypton DAO", "KRD") {
        _mint(msg.sender, 10_000_000_000 * (10**uint256(decimals())));
    }
}
