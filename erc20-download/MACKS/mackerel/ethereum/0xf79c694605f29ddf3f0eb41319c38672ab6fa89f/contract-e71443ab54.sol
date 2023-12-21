// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Permit.sol";

contract Mackerel is ERC20, ERC20Permit {
    constructor() ERC20("Mackerel", "MACKS") ERC20Permit("Mackerel") {
        _mint(msg.sender, 21000000 * 10 ** decimals());
    }
}
