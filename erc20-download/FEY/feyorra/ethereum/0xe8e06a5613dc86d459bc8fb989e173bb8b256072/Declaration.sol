// SPDX-License-Identifier: -- 💰 --

pragma solidity ^0.7.3;

abstract contract Declaration  {

    string public name = "Feyorra";
    string public symbol = "FEY";

    uint256 public decimals = 18;
    uint256 public totalSupply = 1000000000E18;

    uint256 public constant YEARLY_INTEREST = 410;
    uint256 public constant MINIMUM_STAKE = 100E18;
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant MAX_STAKE_DAYS = 1825;

    uint256 public immutable LAUNCH_TIME;

    struct Globals {
        uint256 stakingId;
        uint256 currentFeyDay;
        uint256 totalStakedAmount;
    }

    struct StakeElement {
        address userAddress;
        uint256 stakedAmount;
        uint256 returnAmount;
        uint256 interestAmount;
        uint256 stakedAt;
        bool isActive;
    }

    struct SnapShot {
        uint256 totalSupply;
        uint256 totalStakedAmount;
    }

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    mapping(uint256 => SnapShot) public snapshots;
    mapping(uint256 => StakeElement) public stakeList;

    Globals public globals;

    modifier incrementId() {
        _;
        globals.stakingId++;
    }

    constructor() {
        LAUNCH_TIME = block.timestamp;
        balances[msg.sender] = totalSupply;
    }
}