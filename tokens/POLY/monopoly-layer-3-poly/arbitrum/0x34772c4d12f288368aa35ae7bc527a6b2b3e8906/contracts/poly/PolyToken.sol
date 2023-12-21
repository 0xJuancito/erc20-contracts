// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract PolyToken is ERC20Permit {
    constructor()
        ERC20("Monopoly Layer-3 Token", "POLY")
        ERC20Permit("Monopoly Layer-3 Token")
    {
        _mint(msg.sender, 7_137_536 * 10 ** decimals());
    }
}
