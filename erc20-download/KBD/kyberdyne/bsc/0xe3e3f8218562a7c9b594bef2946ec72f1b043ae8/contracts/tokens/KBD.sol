// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KBD is ERC20 {
    constructor()
    ERC20("Kyberdyne", "KBD"){
        _mint(msg.sender, 5 * 10 ** 8 * 10 ** 18);
    }
}
