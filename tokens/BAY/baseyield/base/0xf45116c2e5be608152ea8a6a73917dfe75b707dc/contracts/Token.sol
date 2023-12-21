//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BaseYieldToken is ERC20 {
    constructor() ERC20("BaseYield", "BAY") {
        _mint(msg.sender, 200000000e18);
    }
}
