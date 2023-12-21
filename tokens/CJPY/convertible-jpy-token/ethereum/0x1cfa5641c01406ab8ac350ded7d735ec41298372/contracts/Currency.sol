pragma solidity 0.8.4;

/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Written by 0xMotoko (0xmotoko@pm.me)
 * Copyright (C) 2021 Yamato Protocol (DeFiGeek Community Japan)
 */

//solhint-disable max-line-length
//solhint-disable no-inline-assembly

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./Interfaces/ICurrency.sol";

/**
 * @author 0xMotoko
 * @title CToken (Convertible Token).
 * @notice Very stable.
 */
contract Currency is ERC20Permit, ICurrency {
    address currencyOS;
    address governance;

    constructor(
        string memory name,
        string memory symbol
    ) ERC20Permit(name) ERC20(name, symbol) {
        governance = msg.sender;
    }

    event CurrencyOSSet(address currencyOSAddr);
    event RevokeGovernance(address _sender);

    modifier onlyCurrencyOS() {
        require(msg.sender == currencyOS, "You are not CurrencyOS contract.");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "You are not the governer.");
        _;
    }

    function mint(address to, uint256 amount) public override onlyCurrencyOS {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public override onlyCurrencyOS {
        _burn(to, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        require(
            _msgSender() != spender,
            "sender and spender shouldn't be the same."
        );
        require(amount > 0, "Amount is zero.");

        _approve(_msgSender(), spender, amount);
        return true;
    }

    function setCurrencyOS(address _currencyOSAddr) public onlyGovernance {
        require(
            _currencyOSAddr != address(0),
            "CurrencyOS address is null address."
        );
        currencyOS = _currencyOSAddr;
        emit CurrencyOSSet(currencyOS);
    }

    function revokeGovernance() public onlyGovernance {
        governance = address(0);
        emit RevokeGovernance(msg.sender);
    }
}
