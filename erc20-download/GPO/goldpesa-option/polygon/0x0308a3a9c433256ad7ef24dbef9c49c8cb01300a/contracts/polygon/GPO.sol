// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./GPOETH.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
____________________________
Description:
GoldPesa Option Contract (GPO) - 1 GPO represents the option to purchase 1 GPX at spot gold price + 1 %.
__________________________________
 */
contract GPOMatic is GPOEth {

    /**
     * @dev Initializes the GPO Matic contract
     */
    constructor(ISwapRouter _swapRouter) GPOEth(_swapRouter) {
    }

}