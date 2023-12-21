// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20PermitUpgradeable} from "openzeppelin-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";

interface IMETH is IERC20Upgradeable, IERC20PermitUpgradeable {
    /// @notice Mint mETH to the staker.
    /// @param staker The address of the staker.
    /// @param amount The amount of tokens to mint.
    function mint(address staker, uint256 amount) external;

    /// @notice Burn mETH from the msg.sender.
    /// @param amount The amount of tokens to burn.
    function burn(uint256 amount) external;
}
