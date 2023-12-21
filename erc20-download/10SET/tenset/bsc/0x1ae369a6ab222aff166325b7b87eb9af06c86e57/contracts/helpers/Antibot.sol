// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.10;

import { Ownable } from "./Ownable.sol";

contract Antibot is Ownable {
    bool public isAntibotEnabled = true;
    mapping(address => mapping(address => uint256)) private transactions;
    mapping(address => bool) private allowedBots;

    event AllowedBotUpdated(address indexed account, bool allowed);
    event AntibotEnabled();
    event AntibotDisabled();

    modifier transactionThrottler(
        address _sender,
        address _recipient,
        uint256 _amount
    ) {
        if (isAntibotEnabled && !allowedBots[_sender] && !allowedBots[_recipient]) {
            require(
                transactions[_sender][_recipient] < block.number - 1 && transactions[_recipient][_sender] < block.number - 1,
                "Antibot: Transaction throttled"
            );
        }
        transactions[_sender][_recipient] = block.number;
        _;
    }

    function setAllowedBot(address _account, bool allowed) external onlyOwner {
        allowedBots[_account] = allowed;
        emit AllowedBotUpdated(_account, allowed);
    }

    function toggleAntibot() external onlyOwner {
        isAntibotEnabled = !isAntibotEnabled;
        if (isAntibotEnabled) {
            emit AntibotEnabled();
        } else {
            emit AntibotDisabled();
        }
    }
}
