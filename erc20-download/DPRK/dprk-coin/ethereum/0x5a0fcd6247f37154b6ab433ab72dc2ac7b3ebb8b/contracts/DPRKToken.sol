// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DPRKToken is ERC20 {
    constructor() ERC20("DPRK Coin", "DPRK") {
        _mint(msg.sender, 888888888888888888 * 10**8);
    }
    function decimals() override public pure returns (uint8) {
        return 8;
    }
}
