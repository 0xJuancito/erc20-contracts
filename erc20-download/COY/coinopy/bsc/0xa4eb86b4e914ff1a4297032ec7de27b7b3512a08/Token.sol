// SPDX-License-Identifier: MIT
//Website: https://coinopy.com
//Telegram: https://t.me/coinopy
//X: https://x.com/coinopycom

pragma solidity ^0.8.9;

import "ERC20.sol";

contract CoinopyToken is ERC20 {
    constructor() ERC20("COINOPY", "COY") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}