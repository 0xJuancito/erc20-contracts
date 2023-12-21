// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ILocker.sol";

interface IVLMGP is ILocker {

    function MGP() external view returns(IERC20);
}