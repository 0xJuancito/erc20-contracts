// SPDX-License-Identifier: UNLICENSED



pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20D is IERC20 {
    function decimals() external returns (uint8);
    function _taxFee() external returns(uint256);
}
