// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "ERC20BurnableUpgradeable.sol";
import "OwnableUpgradeable.sol";
import "ContextUpgradeable.sol";
import "Initializable.sol";

/**
 * @title ERC20PresetMinterBurnableUpgradeable
 * @dev erc20 token template
 */
abstract contract ERC20PresetMinterBurnableUpgradeable is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable
{
    function initialize(string memory nameValue, string memory symbolValue, address ownerValue) external virtual initializer {
        __ERC20PresetMinterBurnable_init(nameValue, symbolValue, ownerValue);
    }

    function __ERC20PresetMinterBurnable_init(string memory nameValue, string memory symbolValue, address ownerValue) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained(nameValue, symbolValue);
        __ERC20Burnable_init_unchained();
        __ERC20PresetMinterBurnable_init_unchained(ownerValue);
    }

    function __ERC20PresetMinterBurnable_init_unchained(address ownerValue) internal initializer {
        transferOwnership(ownerValue);
    }

    /**
     * @dev Mints `amount` new tokens for `to`.
     * See {ERC20-_mint}.
     */
    function mint(address to, uint256 amount) public onlyOwner virtual {
        _mint(to, amount);
    }

    uint256[10] private __gap_ERC20PresetMinterBurnableUpgradeable;
}
