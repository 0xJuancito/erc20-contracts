// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ERC20.sol";

contract ShredN is ERC20 {
    constructor() ERC20("ShredN", "SHRED") {
        _mint(msg.sender, 100_000_000 * (10**uint256(decimals())));
    }
}
