// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.0;

contract CoinCoin is ERC20, Ownable {
    constructor() ERC20("COIN", "COIN") {
        _mint(msg.sender, 231489000 * 10 ** decimals());
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
