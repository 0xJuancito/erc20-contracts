// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./EMBR.sol";

import "solmate/tokens/ERC20.sol";

contract PersonalVester {
    // This is set in constructor
    address public claimer;
    EMBRToken public embr;
    uint public vestingTime;
    uint public cliff;
    uint public totalTokens;

    // This is set in startVest()
    uint public startingTime;

    uint public totalClaimed;

    uint256 public precision = 10e9;

    constructor(uint _totalTokens, uint _vestingTime, uint _cliff, address _claimer){
        totalTokens = _totalTokens;
        vestingTime = _vestingTime;
        cliff = _cliff;
        claimer = _claimer;
        // this contract is only deployed by embr
        // embr = EMBRToken(msg.sender);
    }

    // This function is only called by esEMBR contract. esEMBR also calls claim for this user.
    function startVest() external {
        require(msg.sender == address(embr), "caller must be embr contract");
        startingTime = block.timestamp;
    }

    function claim() public returns (uint256) {
        require(msg.sender == claimer, "invalid caller");
        require(startingTime != 0, "vesting is not started");
        require(block.timestamp > startingTime + cliff, "cliff not reached!");

        uint passedTime = block.timestamp - startingTime;
        if (passedTime > vestingTime) passedTime = vestingTime;

        uint totalClaimableTokens = totalTokens * precision * passedTime / vestingTime / precision;
        uint toClaim = totalClaimableTokens - totalClaimed;

        totalClaimed += toClaim;

        embr.transfer(msg.sender, toClaim);

        return toClaim;
    }

    function claimable() external view returns (uint256) {
        if (startingTime == 0) return 0;
        if (block.timestamp < startingTime + cliff) return 0;
        uint passedTime = block.timestamp - startingTime;
        if (passedTime > vestingTime) passedTime = vestingTime;

        uint totalClaimableTokens = totalTokens * precision * passedTime / vestingTime / precision;
        uint toClaim = totalClaimableTokens - totalClaimed;
        return toClaim;
    }
}
