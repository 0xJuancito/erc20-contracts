// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IWXDAI is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;

    function approve(address guy, uint256 wad) external returns (bool);

    function transferFrom(address src, address dst, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function name() external view returns (string memory);
}
