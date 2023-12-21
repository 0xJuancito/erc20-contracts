// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Gascoin  is ERC20 , Ownable {

    uint256 public constant MAX_SUPPLY = 12500000000000e18;

    constructor() ERC20("Gascoin ", "GCN") {}

    function mint(address account, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(account, amount);
    }
}