// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract CRDSUpgradeable is OwnableUpgradeable, ERC20PermitUpgradeable {
    function __CRDSUpgradeable_init(string memory name, string memory symbol, uint totalSupply, address richer) external initializer() {
        __Ownable_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Permit_init(name);
        _mint(richer, totalSupply);
    }

    uint[50] private __gap;
}