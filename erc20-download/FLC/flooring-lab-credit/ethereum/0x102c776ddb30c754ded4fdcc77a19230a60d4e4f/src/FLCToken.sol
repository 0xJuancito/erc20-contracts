// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FLCToken is ERC20 {
    uint256 private constant TOTAL_SUPPLY = 25_000_000_000;

    constructor() ERC20("Flooring Lab Credit", "FLC") {
        _mint(msg.sender, TOTAL_SUPPLY * (10 ** decimals()));
    }
}
