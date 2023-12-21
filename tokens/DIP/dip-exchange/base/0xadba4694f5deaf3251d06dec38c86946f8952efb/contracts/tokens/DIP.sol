// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DIP is ERC20Burnable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    constructor() ERC20("DIP Token", "DIP") {
        _mint(_msgSender(), MAX_SUPPLY);
    }
}
