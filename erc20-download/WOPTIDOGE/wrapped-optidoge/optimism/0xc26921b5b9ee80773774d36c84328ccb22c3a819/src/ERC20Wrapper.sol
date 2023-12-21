// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Wrapper is ERC20 {
    IERC20Metadata public immutable underlying;

    constructor(IERC20Metadata _underlying)
        ERC20(string(abi.encodePacked("Wrapped ", _underlying.name())), string(abi.encodePacked("w", _underlying.symbol())))
    {
        require(_underlying != this, "Cannot self wrap");
        underlying = _underlying;
    }

    /**
     * Get the number of decimals for this otken.
     */
    function decimals() public view override returns (uint8) {
        return underlying.decimals();
    }

    /**
     * Wrap tokens.
     * @dev Needs token approval.
     * @param amount Amount of tokens that should be wrapped.
     */
    function wrap(uint256 amount) public {
        // Record this contract's balance of the underlying token before any transfers happen.
        uint256 balanceBefore = underlying.balanceOf(address(this));

        // Transfer tokens from the user to this contract.
        underlying.transferFrom(msg.sender, address(this), amount);

        // We calculate the number of wrapper tokens to mint based on the change in balance.
        // This is required because the number of tokens received does not necessarily map 1:1 to `amount`
        // because of burn/fee-on-transfer mechanisms.
        uint256 transferredAmount = underlying.balanceOf(address(this)) - balanceBefore;

        // Mint wrapper tokens to the user.
        _mint(msg.sender, transferredAmount);
    }

    /**
     * Unwrap tokens.
     * @param amount Amount of wrapped tokens to burn.
     */
    function unwrap(uint256 amount) public {
        // Burn the specified amount of wrapper tokens.
        _burn(msg.sender, amount);

        // Transfer the same amount of underlying tokens back to the user.
        // Note that the amount received can be less due to burn/fee-on-transfer mechanisms.
        underlying.transfer(msg.sender, amount);
    }
}
