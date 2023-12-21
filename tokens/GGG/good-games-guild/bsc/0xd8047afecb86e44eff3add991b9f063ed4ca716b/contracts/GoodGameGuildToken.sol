// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GoodGameGuildToken is Ownable, ERC20Burnable {
    constructor(address wallet, uint256 totalSupply) Ownable() ERC20("Good Games Guild","GGG") {
        _mint(wallet, totalSupply);
        transferOwnership(wallet);
    }
}