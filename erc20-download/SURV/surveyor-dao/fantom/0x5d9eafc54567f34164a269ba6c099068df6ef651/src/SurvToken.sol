// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SurvToken is ERC20Burnable, Ownable {

    uint256 public immutable maxSupply = 25000000 ether;

    constructor() ERC20("SurvToken", "SURV") {
        _mint(0x91b331dbb368A89EdB9Bb3e2A7e16b1A4e18B43D, 17500000 ether); //Emissions and Airdrop wallet
        _mint(0x1a4eA35FF39a886B8EDf347712B02A1A1fBbF2a6, 2500000 ether); //Team Wallet
        _mint(0xebb8eE4722501358bf70559d26Ef6e7B1326b3c6, 5000000 ether); //Treasury and Initial Liquidity
    }

}
