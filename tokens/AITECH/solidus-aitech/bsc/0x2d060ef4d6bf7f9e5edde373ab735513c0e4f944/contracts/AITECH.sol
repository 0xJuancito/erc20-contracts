// SPDX-License-Identifier: MIT

//** AITECH Token ERC20 Token for Mainnet */
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract AITECH is ERC20Burnable {
    constructor() ERC20("AITECH", "AITECH") {
        _mint(msg.sender, 2_000_000_000 * 10 ** decimals());
    }
}