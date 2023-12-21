// SPDX-License-Identifier: BUSL1.1
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Kernel, Module, Keycode} from "Default/Kernel.sol";


contract GMBL is ERC20, Module {
    error GMBL_Mint_MaxSupplyExceeded();

    /// @notice maximum totalSupply
    uint256 public maxSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxSupply_,
        Kernel kernel_
    ) ERC20(name_, symbol_, decimals_) Module(kernel_) {
        maxSupply = maxSupply_;
    }

    /// @inheritdoc Module
    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("GMBLE");
    }

    /// @notice Default-compatible permissioned mint for token module
    /// @param to Address to be credited minted supply
    /// @param amount Amount to credit
    function mint(address to, uint256 amount) external permissioned {
        _mint(to, amount);
    }

    /// @notice Burn `amount` of msg.sender's tokens
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Custom implementation of Solmate ERC20 `mint`
    /// @dev totalSupply cannot exceed maximum supply
    /// @param to Address to mint to
    /// @param amount Amount to mint
    function _mint(address to, uint256 amount) internal override {
        totalSupply += amount;

        if (totalSupply > maxSupply) revert GMBL_Mint_MaxSupplyExceeded();

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }
}
