// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

uint256 constant MAGNITUDE = 2 ** 128;

struct RewardToken {
  address token;
  address router;
  address[] path;
  bool useV3;
  bytes pathV3;
}

struct Map {
  address[] keys;
  mapping(address => uint256) values;
  mapping(address => uint256) indexOf;
  mapping(address => bool) inserted;
}

struct RewardStorage {
  mapping(address => int256) magnifiedReward;
  mapping(address => uint256) withdrawnReward;
  mapping(address => uint256) claimTimes;
  mapping(address => bool) manualClaim;
  mapping(address => uint256) rewardBalances;
  uint256 totalRewardSupply;
  RewardToken rewardToken;
  RewardToken goHam;
  Map rewardHolders;
  uint256 magnifiedRewardPerShare;
  uint256 minRewardBalance;
  uint256 totalAccruedReward;
  uint256 lastProcessedIndex;
  uint32 claimTimeout;
}
