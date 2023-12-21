// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IveLNDX {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}