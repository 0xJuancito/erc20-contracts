// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MegaMaker is ERC20, ERC20Burnable {
    constructor(address poolAdm,address poolLabs) ERC20("MAKERX", "MAKERX") {
        uint256 totalToMint = 1000000000 * 10 ** decimals();
        _mint(poolAdm, totalToMint*99/100);
        _mint(poolLabs, totalToMint*1/100);
    }
} 
