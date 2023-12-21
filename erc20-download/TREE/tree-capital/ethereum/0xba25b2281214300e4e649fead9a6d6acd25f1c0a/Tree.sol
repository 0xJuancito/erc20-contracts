// SPDX-License-Identifer: MIT
/*
    Twitter: https://twitter.com/News_Of_Alpha
    Website: https://news.treeofalpha.com
    Discord: https://news.treeofalpha.com/discord
*/
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/access/Ownable.sol";

contract Tree is ERC20, ERC20Permit, Ownable {
    
    bool public initialized = false;
    constructor() ERC20("Tree", "TREE") ERC20Permit("Tree") Ownable(msg.sender) {
    }

    function initialize(address _addr) external onlyOwner {
        require(!initialized, "Already initialized");
        initialized = true;
        _mint(_addr, 200_000_000 * 10 ** decimals());
    } 
}
