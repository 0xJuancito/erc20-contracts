// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        _mint(_msgSender(), totalSupply_);
    }

    function withdraw(
        address payable to,
        address token,
        uint256 amount
    ) public onlyOwner {
        if (token == address(0)) {
            require(address(this).balance >= amount, "Error: Exceeds balance");
            (bool success, ) = to.call{ value: amount }("");
            require(success, "Error: Transfer failed");
        } else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "Error: Exceeds balance");
            require(IERC20(token).transfer(to, amount), "Error: Transfer failed");
        }
    }
}
