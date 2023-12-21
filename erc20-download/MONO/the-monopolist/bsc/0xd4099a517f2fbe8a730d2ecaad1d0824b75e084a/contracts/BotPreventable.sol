// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IBP.sol";

contract BotPreventable is Ownable {
    IBP public botPrevent;
    bool public botPreventEnabled;

    event BotPreventAdded(IBP indexed botPrevent);
    event BotPreventEnabled(bool indexed enabled);
    event BotPreventTransfer(address sender, address recipient, uint256 amount);

    modifier preventTransfer(address sender, address recipient, uint256 amount) {
        if (botPreventEnabled) {
            botPrevent.protect(sender, recipient, amount);

            emit BotPreventTransfer(sender, recipient, amount);
        }

        _;
    }

    function setBotPrevent(IBP botPrevent_) external onlyOwner {
        require(address(botPrevent) == address(0), "Can only be initialized once");
        botPrevent = botPrevent_;

        emit BotPreventAdded(botPrevent_);
    }

    function setBotPreventEnabled(bool botPreventEnabled_) external onlyOwner {
        require(address(botPrevent) != address(0), "You have to set BotPrevent address first");
        botPreventEnabled = botPreventEnabled_;

        emit BotPreventEnabled(botPreventEnabled_);
    }
}
