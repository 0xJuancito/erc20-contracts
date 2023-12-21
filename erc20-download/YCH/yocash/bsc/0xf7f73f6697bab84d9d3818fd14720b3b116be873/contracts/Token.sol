//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YoCash is ERC20 {
    
    uint public _totalSupply = 500000000 * 10 ** decimals();

    constructor() ERC20("YoCash", "YCH") {
        _mint(msg.sender, _totalSupply);
    }
}

