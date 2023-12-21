//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../utils/TokenWithdrawable.sol";

contract FaraCrystal is ERC20, ERC20Burnable, TokenWithdrawable {
    constructor() ERC20("FaraCrystal", "FARA") {
        _mint(msg.sender, 1e26);
    }
}