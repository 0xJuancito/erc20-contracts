// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.2/access/Ownable.sol";

contract PrecipitateAI is ERC20, Ownable {
    constructor() ERC20("Precipitate.AI", "RAIN") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}
