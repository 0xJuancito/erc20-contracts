// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MinnaToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("MINNA", "MINNA") {
        _mint(
            0x008165BC5c32EA374B588742679cB8384F432b17,
            1000000000 * 10 ** decimals()
        );
    }
}
