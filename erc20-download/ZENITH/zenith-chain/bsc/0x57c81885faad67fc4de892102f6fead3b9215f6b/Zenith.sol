// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BEP20Burnable.sol";

/**
 * @dev {BEP20} token, including:
 *
 *  - Preminted initial supply
 *  - Ability for holders to burn (destroy) their tokens
 *  - No access control mechanism (for minting/pausing) and hence no governance
 *
 * This contract uses {BEP20Burnable} to include burn capabilities - head to
 * its documentation for details.
 *
 * _Available since v3.4._
 */
contract Zenith is BEP20Burnable {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {BEP20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) BEP20(name, symbol) {
        _mint(owner, initialSupply);
    }
}
