// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract NGT is ERC20Upgradeable, OwnableUpgradeable {

    function initialize() public initializer
    {
        __ERC20_init("NGT", "NGT");
        __Ownable_init();
    }

    function approveForContract(address spender) public onlyOwner
    {
        _approve(address(this), spender, type(uint256).max);
    }

    function mint(address to, uint256 amount) public onlyOwner
    {
        _mint(to, amount);
    }

    function tokenWithdraw(address to, uint256 amount) external returns (bool)
    {
        return transfer(to, amount);
    }
}