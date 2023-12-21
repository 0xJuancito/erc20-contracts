// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract FLOYXTOKEN is ERC20, ERC20Burnable, Ownable {
    error MaxAmountExceeded();
    error tokenAmountMustBeMorethan0();
    error burnAmountExceedsBalance();

    uint256 public constant MAX_SUPPLY = 50000000000 ether;

    constructor() ERC20("FLOYX TOKEN", "FLOYX") {}

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        uint256 totalAmount = amount + totalSupply();
        if (MAX_SUPPLY <= totalAmount) {
            revert MaxAmountExceeded();
        }
        _mint(to, amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert tokenAmountMustBeMorethan0();
        }
        if (balance < _amount) {
            revert burnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}
