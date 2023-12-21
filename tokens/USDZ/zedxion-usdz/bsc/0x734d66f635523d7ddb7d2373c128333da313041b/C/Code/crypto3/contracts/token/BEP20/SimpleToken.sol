// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/BEP20.sol";

import "../../service/CommissionPayer.sol";

/**
 * @title SimpleToken
 * @dev Implementation of the SimpleToken
 */
contract SimpleToken is BEP20, CommissionPayer {

    constructor (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialBalance_,
        address payable commissionReceiver_,
        string memory discountCode
    )
    BEP20(name_, symbol_)
    CommissionPayer(commissionReceiver_, "SimpleToken", discountCode)
    payable
    {
        require(initialBalance_ > 0, "SimpleToken: supply cannot be zero");
        _setupDecimals(decimals_);
        _mint(_msgSender(), initialBalance_);
    }
}
