// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./Erc20PresetUpgradeable.sol";

abstract contract ERC20CappedPresetUpgradeable is ERC20CappedUpgradeable, Erc20PresetUpgradeable {
    /**
     * @dev initializes contract
     */
    function __ERC20CappedPresetUpgradeable_init(
        string memory _name,
        string memory _symbol,
        uint256 _cap
    ) public initializer {
        Erc20PresetUpgradeable.__Erc20PresetUpgradeable_init(_name, _symbol);
        __ERC20CappedPresetUpgradeable_init_unchained(_cap);
    }

    function __ERC20CappedPresetUpgradeable_init_unchained(uint256 _cap) public initializer {
        ERC20CappedUpgradeable.__ERC20Capped_init_unchained(_cap);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override(Erc20PresetUpgradeable, ERC20Upgradeable) {
        super._beforeTokenTransfer(_from, _to, _amount);
    }

    function mint(address _account, uint256 _amount) external virtual override onlyRole(MINTER_ROLE) {
        _mint(_account, _amount);
    }

    function _mint(address _account, uint256 _amount) internal virtual override(ERC20CappedUpgradeable, Erc20PresetUpgradeable) {
        super._mint(_account, _amount);
    }

    uint256[50] private __gap;
}
