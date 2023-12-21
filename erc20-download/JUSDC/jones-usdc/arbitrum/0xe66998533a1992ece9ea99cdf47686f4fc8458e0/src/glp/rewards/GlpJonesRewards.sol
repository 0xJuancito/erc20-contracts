// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Operable, Governable} from "../../common/Operable.sol";

contract GlpJonesRewards is Operable, ReentrancyGuard {
    IERC20 public immutable rewardsToken;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Timestamp of when the rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;

    // Total staked
    uint256 public totalSupply;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;

    constructor(address _rewardToken) Governable(msg.sender) ReentrancyGuard() {
        rewardsToken = IERC20(_rewardToken);
    }

    // ============================= Modifiers ================================ //

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    // ============================= Operator functions ================================ //

    /**
     * @notice Virtual Stake, an accountability of the deposit
     * @dev No asset are transferred here is it just the accountability
     * @param _user Address of depositor
     * @param _amount Amount deposited
     */
    function stake(address _user, uint256 _amount) external onlyOperator updateReward(_user) {
        if (_amount == 0) {
            revert ZeroAmount();
        }
        balanceOf[_user] += _amount;
        totalSupply += _amount;

        emit Stake(_user, _amount);
    }

    /**
     * @notice Virtual withdraw, an accountability of the withdraw
     * @dev No asset have to be transfer here is it just the accountability
     * @param _user Address of withdrawal
     * @param _amount Amount to withdraw
     */
    function withdraw(address _user, uint256 _amount) external onlyOperator updateReward(_user) {
        if (_amount == 0) {
            revert ZeroAmount();
        }
        balanceOf[_user] -= _amount;
        totalSupply -= _amount;

        emit Withdraw(_user, _amount);
    }

    /**
     * @notice Transfer respective rewards, Jones emissions, to the _user address
     * @param _user Address where the rewards are transferred
     * @return Amount of rewards, Jones emissions
     */
    function getReward(address _user) external onlyOperator updateReward(_user) nonReentrant returns (uint256) {
        uint256 reward = rewards[_user];
        if (reward > 0) {
            rewards[_user] = 0;
            rewardsToken.transfer(_user, reward);
        }

        emit GetReward(_user, reward);

        return reward;
    }

    // ============================= Public functions ================================ //

    /**
     * @notice Return the last time a reward was applie
     * @return Timestamp when the last reward happened
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    /**
     * @notice Return the amount of reward per tokend deposited
     * @return Amount of rewards, jones emissions
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    /**
     * @notice Return the total jones emissions earned by an user
     * @return Total emissions earned
     */
    function earned(address _user) public view returns (uint256) {
        return ((balanceOf[_user] * (rewardPerToken() - userRewardPerTokenPaid[_user])) / 1e18) + rewards[_user];
    }

    // ============================= Governor functions ================================ //

    /**
     * @notice Set the duration of the rewards
     * @param _duration timestamp based duration
     */
    function setRewardsDuration(uint256 _duration) external onlyGovernor {
        if (block.timestamp <= finishAt) {
            revert DurationNotFinished();
        }

        duration = _duration;

        emit UpdateRewardsDuration(finishAt, _duration + block.timestamp);
    }

    /**
     * @notice Notify Reward Amount for a specific _amount
     * @param _amount AMount to calculate the rewards
     */
    function notifyRewardAmount(uint256 _amount) external onlyGovernor updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        if (rewardRate == 0) {
            revert ZeroRewardRate();
        }
        if (rewardRate * duration > rewardsToken.balanceOf(address(this))) {
            revert NotEnoughBalance();
        }

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;

        emit NotifyRewardAmount(_amount, finishAt);
    }

    // ============================= Private functions ================================ //
    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    // ============================= Events ================================ //

    event Stake(address indexed _to, uint256 _amount);
    event Withdraw(address indexed _to, uint256 _amount);
    event GetReward(address indexed _to, uint256 _rewards);
    event UpdateRewardsDuration(uint256 _oldEnding, uint256 _newEnding);
    event NotifyRewardAmount(uint256 _amount, uint256 _finishAt);

    // ============================= Errors ================================ //

    error ZeroAmount();
    error ZeroRewardRate();
    error NotEnoughBalance();
    error DurationNotFinished();
}
