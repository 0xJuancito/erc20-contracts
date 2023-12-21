// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract UtilityWeb3Shot is ERC20 {
    constructor() ERC20("Utility Web3Shot", "UW3S") {
        _mint(msg.sender, 10_000_000_000 * (10**uint256(decimals())));
    }
}
