//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UncleSam is ERC20 {
    constructor() ERC20("UncleSam", "SAM") {
        _mint(msg.sender, 16000000e18);
    }
}
