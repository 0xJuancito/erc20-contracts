// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
 
interface IFID {
    /**
     * @dev Burn - decrease total supply
     */
    function burn(uint256 amount) external;
}