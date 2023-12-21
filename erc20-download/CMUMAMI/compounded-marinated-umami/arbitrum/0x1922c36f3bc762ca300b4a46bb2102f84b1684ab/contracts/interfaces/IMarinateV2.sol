// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMarinateV2 is IERC20 {
    function stake(uint256 amount) external;

    function withdraw() external;

    function claimRewards() external;

    function getAvailableTokenRewards(address staker, address token) external returns (uint256 totalRewards);

    function addApprovedRewardToken(address token) external;

    function addToContractWhitelist(address _contract) external returns (bool);

    function addReward(address token, uint256 amount) external;

    function setDepositLimit(uint256 limit) external;

    function totalTokenRewardsPerStake(address a) external;

    function isWhitelisted(address addr) external returns (bool);
}
