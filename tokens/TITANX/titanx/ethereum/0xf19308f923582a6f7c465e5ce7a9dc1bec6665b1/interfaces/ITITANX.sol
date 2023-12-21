// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface ITITANX {
    function balanceOf(address account) external returns (uint256);

    function getBalance() external;

    function mintLPTokens() external;

    function burnLPTokens() external;
}
