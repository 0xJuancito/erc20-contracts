// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IneryToken is ERC20 {
    uint256 private constant _totalSupply = 800_000_000 ether; // 800M

    constructor () ERC20("INERY", "INR") {
        _mint(msg.sender, _totalSupply);
    }
}
