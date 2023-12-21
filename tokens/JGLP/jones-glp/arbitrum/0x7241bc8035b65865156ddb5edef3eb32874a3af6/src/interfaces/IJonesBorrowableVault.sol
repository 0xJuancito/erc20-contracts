// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

interface IJonesBorrowableVault is IERC4626 {
    function borrow(uint256 _amount) external returns (uint256);
    function repay(uint256 _amount) external returns (uint256);
}
