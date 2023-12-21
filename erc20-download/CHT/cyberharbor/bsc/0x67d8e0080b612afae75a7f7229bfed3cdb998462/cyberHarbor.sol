// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "ERC20.sol";

contract CyberHarbor is ERC20 {
    constructor() ERC20("CyberHarbor", "CHT") {
        _mint(msg.sender, 1_000_000_000 * (10**uint256(decimals())));
    }
}
