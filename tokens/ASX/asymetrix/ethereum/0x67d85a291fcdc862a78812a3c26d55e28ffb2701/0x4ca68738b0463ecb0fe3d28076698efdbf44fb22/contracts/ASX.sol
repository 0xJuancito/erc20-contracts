// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesCompUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ASX is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20CappedUpgradeable,
    ERC20VotesCompUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 cap,
        address initialSupplyReceiver
    ) external initializer {
        __ASX_init(name, symbol, cap, initialSupplyReceiver);
    }

    function __ASX_init(
        string memory name,
        string memory symbol,
        uint256 cap,
        address initialSupplyReceiver
    ) internal onlyInitializing {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __ERC20Capped_init_unchained(cap);
        __ERC20VotesComp_init_unchained();
        __ERC20Votes_init_unchained();
        __ERC20Permit_init_unchained("");
        __EIP712_init_unchained(name, "1");
        __ASX_init_unchained(initialSupplyReceiver, cap);
    }

    function __ASX_init_unchained(
        address initialSupplyReceiver,
        uint256 amount
    ) internal onlyInitializing {
        _mint(initialSupplyReceiver, amount);
    }

    function _mint(
        address to,
        uint256 amount
    )
        internal
        override(
            ERC20Upgradeable,
            ERC20CappedUpgradeable,
            ERC20VotesUpgradeable
        )
    {
        super._mint(to, amount);
    }

    function _burn(
        address from,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(from, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }
}
