// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./IOFTCoreUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the OFT standard
 */
interface IOFTUpgradeable is IOFTCoreUpgradeable, IERC20 {

}
