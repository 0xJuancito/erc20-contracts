// SPDX-License-Identifier: LIC
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact it@gameswift.io
contract GameSwift is ERC20 {
    constructor() ERC20("GameSwift", "GSWIFT") {
        _mint(msg.sender, 1396500000 * 10 ** decimals());
    }
}