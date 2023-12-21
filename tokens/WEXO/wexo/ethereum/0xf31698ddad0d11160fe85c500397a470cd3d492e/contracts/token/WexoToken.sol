// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WexoToken is ERC20 {
    constructor() ERC20("WEXO", "WEXO") {
        _mint(msg.sender, 928000000 * (10 ** 18));
    }

}