// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ERC20.sol";

contract WishMeLuck is ERC20 {
        constructor() ERC20("WishMeLuck", "WML") {
        _mint(_msgSender(), 1000000000 * 10**18);
    }
}
