// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BiFinanceToken is ERC20, Ownable {
    constructor() ERC20("BiFinance Token", "BFT") {
        _mint(msg.sender, 1000000000 * 10**18);
    }
}