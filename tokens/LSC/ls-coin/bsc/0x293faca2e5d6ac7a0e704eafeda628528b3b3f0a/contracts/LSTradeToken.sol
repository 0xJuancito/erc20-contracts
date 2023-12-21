// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LSTradeToken is ERC20Burnable, Ownable {
    uint256 public constant MAX_MINT_AMOUNT = 100000000;
    uint256 public mintedAmount;

    constructor(string memory name, string memory symbol, address owner) ERC20(name, symbol) {
        _transferOwnership(owner);
    }

    function mint(address user, uint256 amount) public virtual onlyOwner returns (bool) {
        require(mintedAmount + amount <= MAX_MINT_AMOUNT * (10 ** decimals()), "Exceeded max mint amount");
        _mint(user, amount);
        mintedAmount += amount;
        return true;
    }
}
