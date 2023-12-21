// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TransactionThrottler } from "../helpers/TransactionThrottler.sol";

contract ERC20Mock is ERC20, TransactionThrottler {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 supply
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        _mint(msg.sender, supply);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override transactionThrottler(sender, recipient) {
        super._transfer(sender, recipient, amount);
    }
}
