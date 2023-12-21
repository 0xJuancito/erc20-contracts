// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.2/token/ERC20/extensions/ERC20Permit.sol";

/// @custom:security-contact info@abachilabs.com
contract Abachi is ERC20, ERC20Permit {
    constructor() ERC20("Abachi", "ABI") ERC20Permit("Abachi") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
