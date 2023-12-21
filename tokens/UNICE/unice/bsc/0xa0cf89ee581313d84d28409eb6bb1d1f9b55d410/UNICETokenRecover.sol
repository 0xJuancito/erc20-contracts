// SPDX-License-Identifier: No License

pragma solidity ^0.8.0;

import "./UNICEIBEP20.sol";
import "./UNICEOwnable.sol";

abstract contract TokenRecover is Ownable {

    function recoverERC20(address tokenAddress, uint256 amount) public onlyOwner {
        require(tokenAddress != address(this), "TokenRecover: Cannot recover this token");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(amount <= balance, "TokenRecover: Amount is greater than balance");

        token.transfer(owner(), amount);
    }

    function withdrawIfAnyEthBalance() external onlyOwner returns (uint256) {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
        return balance;
    }

    function withdrawIfAnyTokenBalance(address tokenAddress) external onlyOwner returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
        return balance;
    }
}
