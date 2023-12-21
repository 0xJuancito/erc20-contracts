// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBP {
    function protect(address sender, address receiver, uint256 amount) external;
}
