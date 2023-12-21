//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import {IERC20Decimals} from "./IERC20Decimals.sol";

interface ISparta is IERC20Decimals {
    function burn(uint256 amount) external;
}
