// SPDX-License-Identifier: NOLICENSE
pragma solidity ^0.8.10;

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addTreasuryETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint treasury);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

}