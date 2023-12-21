// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KUNKUN is ERC20 {
    constructor() ERC20("KUNKUN Coin", "KUNKUN") {
        _mint(msg.sender, 2500000000 * 10 ** decimals());
    }
}