// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract EarnBetCoin is ERC20, ERC20Burnable {

    constructor() ERC20("EarnBet Coin", "EBET") {
        _mint(msg.sender, maxSupply());
    }

    // 8 decimals
    function decimals() public pure override returns (uint8) {
        return 8;
    }

    // 8.8 Billion Tokens with 8 decimals
    function maxSupply() public pure returns (uint256) {
        return 8_800_000_000 * 10**8;
    }
}
