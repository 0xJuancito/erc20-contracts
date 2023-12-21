// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @dev L2 HOP tokens are layer-2 tokens that represent a deposit in the L1_Bridge contract. 
 * Each Hop Bridge Token is a regular ERC20 that can be minted and burned by the L2_Bridge
 * that owns it.
 */

contract L2_HOPToken is ERC20, ERC20Permit, ERC20Votes, Ownable {

    constructor () ERC20("Hop", "HOP") ERC20Permit("Hop") {}

    /**
     * @dev Mint new tokens for the account
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    /**
     * @dev Burn tokens from the account
     * @param account The account being burned from
     * @param amount The amount being burned
     */
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}