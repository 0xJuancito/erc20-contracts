// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";

/*
           __              __
           \ `-._......_.-` /
            `.  '.    .'  .'
             //  _`\/`_  \\
            ||  /\O||O/\  ||
            |\  \_/||\_/  /|
            \ '.   \/   .' /
            / ^ `'~  ~'`   \
           /  _-^_~ -^_ ~-  |
           | / ^_ -^_- ~_^\ |
           | |~_ ^- _-^_ -| |
           | \  ^-~_ ~-_^ / |
           \_/;-.,____,.-;\_/
       =======(_(_(==)_)_)========

    ==================================
*/

contract AthenaDAOToken is ERC20, ERC20Burnable, ERC20Capped, Ownable {
    constructor() ERC20("AthenaDAO Token", "ATH") ERC20Capped(100_000_000 ether) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}
