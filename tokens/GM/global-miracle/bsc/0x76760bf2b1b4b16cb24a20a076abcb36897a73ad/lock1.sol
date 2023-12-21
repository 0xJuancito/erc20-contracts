// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GlobalMiracle is ERC20, Ownable {
    uint256 public unlockStartDate;
    uint256 public unlockPeriod = 30 days;
    uint256 public initialUnlockPercentage = 5;
    uint256 public monthlyUnlockPercentage = 1;

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => LockedBalance) public lockedBalances;

    constructor(string memory name, string memory symbol, uint256 totalSupply) ERC20(name, symbol) {
        _mint(msg.sender, totalSupply);
        unlockStartDate = block.timestamp;
    }

    function initialUnlock() external onlyOwner {
        require(block.timestamp >= unlockStartDate, "Initial unlock has not started yet");
        require(lockedBalances[msg.sender].amount > 0, "No locked balance to unlock");

        uint256 unlockAmount = (lockedBalances[msg.sender].amount * initialUnlockPercentage) / 100;
        lockedBalances[msg.sender].amount -= unlockAmount;
        _transfer(address(this), msg.sender, unlockAmount);
    }

    function monthlyUnlock() external onlyOwner {
        require(block.timestamp >= unlockStartDate, "Unlock period has not started yet");
        uint256 unlockableAmount = ((block.timestamp - unlockStartDate) / unlockPeriod) * (monthlyUnlockPercentage * totalSupply()) / 100;

        uint256 unlockAmount = unlockableAmount - lockedBalances[msg.sender].amount;
        if (unlockAmount > 0) {
            lockedBalances[msg.sender].amount = unlockableAmount;
            _transfer(address(this), msg.sender, unlockAmount);
        }
    }

    // Function to lock tokens for a recipient
    function lockTokens(address recipient, uint256 amount, uint256 unlockTime) external onlyOwner {
        require(amount <= balanceOf(msg.sender), "Insufficient balance");
        lockedBalances[recipient] = LockedBalance(amount, unlockTime);
        _transfer(msg.sender, address(this), amount);
    }
}
