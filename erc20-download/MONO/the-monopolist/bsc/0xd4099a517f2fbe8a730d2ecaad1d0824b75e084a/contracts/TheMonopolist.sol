// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./BotPreventable.sol";

contract TheMonopolist is ERC20, BotPreventable {
    uint256 private constant INITIAL_SUPPLY = 1000000000 ether;

    constructor(
        address owner_,
        string memory tokenName_,
        string memory tokenSymbol_
    ) ERC20(tokenName_, tokenSymbol_) {
        _mint(owner_, INITIAL_SUPPLY);
        transferOwnership(owner_);
    }

    /**
     * @dev Add the BotPrevent handler to prevents the bots.
     *
     **/
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override preventTransfer(sender, recipient, amount) {
        super._transfer(sender, recipient, amount);
    }
}
