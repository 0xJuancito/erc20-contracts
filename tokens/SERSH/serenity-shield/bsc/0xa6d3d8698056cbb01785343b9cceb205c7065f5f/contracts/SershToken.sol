// SPDX-License-Identifier: MIT

//** SerenityShield Token */
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Official SerenityShield Token
/// @author SerenityShield.io
/// @dev A token based on OpenZeppelin's principles

contract SERSHToken is ERC20Burnable {

    /// @notice A constructor that mint the tokens
    constructor() ERC20("SerenityShield", "SERSH") {
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }
}