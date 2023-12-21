// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/ERC20.sol";


contract MarsDAO is ERC20 {
    
    //MarsDAO token
    constructor() public ERC20("MarsDAO", "MDAO") {
        _mint(msg.sender, 100_000_000 * 1e18);
    }

}
