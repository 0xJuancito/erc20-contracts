// SPDX-License-Identifier: GPL-2.0-only
pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Possum is ERC20, ERC20Permit {
    constructor(
        uint256 _totalSupply
    ) ERC20("Possum", "PSM") ERC20Permit("Possum") {
        _mint(msg.sender, _totalSupply); // mint initial supply to deployer
    }
}