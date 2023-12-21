// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import './utils/Withdrawable.sol';
import './utils/Permissioned.sol';
import './utils/AntiBot.sol';
import './utils/Crosschain.sol';

/// @custom:security-contact security@tenset.io
contract Token is ERC20, ERC20Burnable, Crosschain, Withdrawable, Permissioned, AntiBot {
    uint88 private constant MAX_TOTAL_SUPPLY = 21_000_000 ether;

    modifier protectedWithdrawal() override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    constructor(
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PERMITTED_ROLE, _msgSender());
        _mint(_msgSender(), initialSupply);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override onlyPermitted transactionThrottler(from, to) {
        super._transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        require(totalSupply() + amount <= MAX_TOTAL_SUPPLY, 'Can not mint more than 21m tokens');
        super._mint(account, amount);
    }

    function _grantRole(bytes32 role, address account) internal override(AccessControlEnumerable, Crosschain) {
        super._grantRole(role, account);
    }
}
