//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Shill is ERC20("Shill", "SHILL") {
    constructor() {
        _mint(msg.sender, 1_000_000_000 ether); // 1B
    }
}
