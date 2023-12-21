// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../../interfaces/IErc20.sol";
import "../../../../security/MinterPresetUpgradeable.sol";
import "../../../../security/SecurityPresetUpgradeable.sol";

abstract contract Erc20PresetUpgradeable is
    IErc20,
    SecurityPresetUpgradeable,
    MinterPresetUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev initializes contract
     */
    function __Erc20PresetUpgradeable_init(string memory _name, string memory _symbol) public initializer {
        SecurityPresetUpgradeable.__SecurityPresetUpgradeable_init();
        MinterPresetUpgradeable.__MinterPresetUpgradeable_init_unchained();
        __Erc20PresetUpgradeable_init_unchained(_name, _symbol);
    }

    function __Erc20PresetUpgradeable_init_unchained(string memory _name, string memory _symbol) internal initializer {
        ERC20Upgradeable.__ERC20_init_unchained(_name, _symbol);
        ERC20BurnableUpgradeable.__ERC20Burnable_init_unchained();
        ERC20PausableUpgradeable.__ERC20Pausable_init_unchained();
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address account, uint256 amount) external virtual override onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
