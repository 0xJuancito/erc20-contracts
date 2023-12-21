// SPDX-License-Identifier: MIT

//** Synergy Land ERC20 Token for Polygon */
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SNGToken is ERC20Burnable {
    constructor() ERC20("Synergy Land Token", "SNG") {
        _mint(msg.sender, 200000000 * 10 ** decimals());
    }
}