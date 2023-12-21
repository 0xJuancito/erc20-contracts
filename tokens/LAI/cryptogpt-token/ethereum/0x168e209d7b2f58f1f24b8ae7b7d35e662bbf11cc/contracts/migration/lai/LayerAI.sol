// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract LayerAI is ERC20, ERC20Burnable, ERC20Permit {
    uint256 public constant MAX_TOTAL_SUPPLY = 3_000_000_000 ether;

    constructor(
        address _treasury
    ) ERC20("LayerAI Token", "LAI") ERC20Permit("LayerAI Token") {
        _mint(_treasury, 3_000_000_000 ether);
    }
}
