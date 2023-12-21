// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract YAEToken is ERC20, ERC20Burnable {
    // Wrapped token for Cryptonovae (YAE) on Ethereum
    // Official ETH contract: 0x4ee438be38f8682abb089f2bfea48851c5e71eaf

    constructor() ERC20("Cryptonovae", "YAE") {
        _mint(msg.sender, 100000000e18);
    }
}