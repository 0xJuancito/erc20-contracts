// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./BEP20/BEP20Burnable.sol";

contract JumpToken is BEP20Burnable {
    constructor() BEP20("JumpToken", "JMPT") {
        // Mint 100M tokens to creator address
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }
}
