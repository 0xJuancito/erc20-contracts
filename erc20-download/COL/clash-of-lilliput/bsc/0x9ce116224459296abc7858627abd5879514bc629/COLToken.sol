// contracts/PetalsToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract COLToken is ERC20 {
    constructor() ERC20("Clash of lilliput", "COL") {
        _mint(msg.sender, 1_000_000_000 * (10**uint256(decimals())));
    }
}
