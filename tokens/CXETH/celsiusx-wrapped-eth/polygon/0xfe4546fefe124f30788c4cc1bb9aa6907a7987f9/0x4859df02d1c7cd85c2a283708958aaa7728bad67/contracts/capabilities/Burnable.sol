// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../roles/BurnerRole.sol";

/// @title Burnable Contract
/// @notice Only administrators can burn tokens
/// @dev Enables reducing a balance by burning tokens
contract Burnable is ERC20Upgradeable, BurnerRole {
    event Burn(address indexed burner, address indexed from, uint256 amount);

    /// @notice Only administrators should be allowed to burn on behalf of another account
    /// @dev Burn a quantity of token in an account, reducing the balance
    /// @param burner Designated to be allowed to burn account tokens
    /// @param from The account tokens will be deducted from
    /// @param amount The number of tokens to remove from a balance
    function _burn(
        address burner,
        address from,
        uint256 amount
    ) internal returns (bool) {
        ERC20Upgradeable._burn(from, amount);
        emit Burn(burner, from, amount);
        return true;
    }

    /// @dev Allow Burners to burn tokens for addresses
    /// @param account The account tokens will be deducted from
    /// @param amount The number of tokens to remove from a balance
    function burn(address account, uint256 amount)
        external
        onlyBurner
        returns (bool)
    {
        return _burn(msg.sender, account, amount);
    }

    uint256[50] private __gap;
}
