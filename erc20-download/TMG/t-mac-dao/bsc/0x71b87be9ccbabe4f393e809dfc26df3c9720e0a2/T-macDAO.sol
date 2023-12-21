// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract TmacDAO is ERC20 {
    constructor() ERC20("T-mac DAO", "TMG") {
        _mint(msg.sender, 1_000_000_000 * (10**uint256(decimals())));
    }
}
