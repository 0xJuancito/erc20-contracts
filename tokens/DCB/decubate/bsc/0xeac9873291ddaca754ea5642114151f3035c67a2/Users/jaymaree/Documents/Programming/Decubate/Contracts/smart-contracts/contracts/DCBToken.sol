// SPDX-License-Identifier: MIT

//** Decubate ERC20 TOKEN for Mainnet */
//** Author Alex Hong : Decubate Crowfunding 2021.6 */

pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/DCBWhitelisted.sol";

contract DCBToken is ERC20, DCBWhitelisted, Ownable {
    using SafeMath for uint256;

    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    /**
     *
     * @dev mint initialSupply in constructor with symbol and name
     *
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public ERC20(name, symbol) {
        _mint(_msgSender(), initialSupply);
    }

    /**
     *
     * @dev lock tokens by sending to DEAD address
     *
     */
    function lockTokens(uint256 amount) external onlyOwner returns (bool) {
        _transfer(_msgSender(), DEAD_ADDRESS, amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        _applyLGEWhitelist(from, to, amount);
    }
}
