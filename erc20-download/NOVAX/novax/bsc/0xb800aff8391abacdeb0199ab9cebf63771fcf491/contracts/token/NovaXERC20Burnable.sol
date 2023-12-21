// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/NovaXERC20.sol.sol/extensions/NovaXERC20Burnable.sol.sol)

pragma solidity ^0.8.0;

import "./NovaXERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Extension of {NovaXERC20.sol.sol} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract NovaXERC20Burnable is Context, NovaXERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {NovaXERC20.sol.sol-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {NovaXERC20.sol.sol-_burn} and {NovaXERC20.sol.sol.sol-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
