// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WAR is ERC20 {
    constructor() ERC20("WAR", "WAR") {
        _mint(msg.sender, 100000000 ether);
    }
}
