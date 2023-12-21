// SPDX-License-Identifier: MIT
// Empty Gap contract. Used when a contract that previously had a __gap variable was removed

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Empty Gap contract. Used when a contract that previously had a __gap variable was removed
 */
abstract contract EmptyGap is Initializable, ERC20Upgradeable {
    function __ERC20FlashMint_init() internal onlyInitializing {}

    function __ERC20FlashMint_init_unchained() internal onlyInitializing {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
