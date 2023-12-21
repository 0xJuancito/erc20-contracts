// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IBotPrevention {
    function protect(address sender, address receiver, uint256 amount) external;
}
