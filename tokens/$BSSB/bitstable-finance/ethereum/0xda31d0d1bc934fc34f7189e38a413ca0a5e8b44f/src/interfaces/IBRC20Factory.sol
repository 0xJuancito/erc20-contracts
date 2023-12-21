// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IBRC20Factory {
    function parameters() external view returns (string memory name, string memory symbol, uint8 decimals);
}