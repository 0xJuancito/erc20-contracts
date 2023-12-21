// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC20Burnable} from "burnable.sol";
import {ERC20Mintable} from "mintable.sol";
import {ERC20} from "ERC20.sol";

/**
 * Wrapped Okcash
 * Implementation of the Wrapped Okcash
 */
contract OkcashToken is ERC20Mintable, ERC20Burnable {
    constructor() ERC20("Okcash", "OK") {
        _setupDecimals(18);
        //_mint(_msgSender(), 0);
        transferOwnership(0x362f16bcCA3c909DeA88898f406C7D9ffb48361E);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override onlyOwner {
        super._mint(account, amount);
    }

    function _finishMinting() internal override onlyOwner {
        super._finishMinting();
    }
}
