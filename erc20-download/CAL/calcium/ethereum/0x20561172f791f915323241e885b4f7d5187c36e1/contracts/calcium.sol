// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Calcium is ERC20 {
    constructor() ERC20("Calcium", "CAL") {
        _mint(msg.sender, 420690000 * 10 ** decimals());
    }
}