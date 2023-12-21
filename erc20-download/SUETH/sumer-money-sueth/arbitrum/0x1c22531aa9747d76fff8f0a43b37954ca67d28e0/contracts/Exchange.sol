// Copyright (c) 2018 The Meter.io developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>
pragma solidity ^0.8.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Exchange is Ownable {
    address public tokenIn;
    address public tokenOut;
    uint256 public exchangeRate;
    uint256 public rateDenominator = 10000;
    uint256 public tokenInReserve;

    constructor(
        address _tokenIn,
        address _tokenOut,
        uint256 _exchangeRate
    ) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        exchangeRate = _exchangeRate;
    }

    function adminSetExchangeRate(uint256 _exchangeRate) public onlyOwner {
        require(_exchangeRate > 0, "exchangeRate is zero");
        exchangeRate = _exchangeRate;
    }

    function adminWithdraw(uint256 amount) public onlyOwner {
        IERC20(tokenOut).transfer(msg.sender, amount);
    }

    function change(uint256 amount) public {
        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        require(
            IERC20(tokenIn).balanceOf(address(this)) - balanceBefore >= amount,
            "transfer fail"
        );
        tokenInReserve += amount;
        uint256 amountOut = (amount * exchangeRate) / rateDenominator;
        require(
            IERC20(tokenOut).balanceOf(address(this)) >= amountOut,
            "Insufficient balance"
        );
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }
}
