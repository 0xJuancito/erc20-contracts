// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract BurntGrumpyCat is ERC20, Ownable {
    constructor() ERC20("Burnt Grumpy Cat", "BGC") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
