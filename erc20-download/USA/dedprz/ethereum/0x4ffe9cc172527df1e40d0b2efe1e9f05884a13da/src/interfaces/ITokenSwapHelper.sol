// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ITokenSwapHelper {
    function swapTokenForETH(uint256 amountIn, uint256 amountOutMin) external;
}
