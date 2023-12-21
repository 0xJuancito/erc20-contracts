
// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

/**
   Entity that generates financial return for it's investors
*/
interface IYielder {
  // Rreturns the pending reward for a given investor
  function pendingReward(address _investor) external view returns (uint256);

  // Claims rewards for the calling investor
  function claimRewardTo(uint256 amount, address receiver) external;

  // Claims rewards for the calling investor
  function claimReward(uint256 amount) external;

  // Yielder may accept funds from investors;
  function deposit(uint256 amount) external;

  // Withdraw funds
  function withdraw(uint256 amount) external;
}