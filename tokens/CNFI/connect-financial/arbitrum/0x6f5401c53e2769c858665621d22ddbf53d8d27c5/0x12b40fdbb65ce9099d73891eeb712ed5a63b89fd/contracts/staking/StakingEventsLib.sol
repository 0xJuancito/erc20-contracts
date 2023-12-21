// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

library StakingEventsLib {
  event Redeemed(address indexed user, uint256 amountToRedeem, uint256 bonuses);
  function _emitRedeemed(address user, uint256 amountToRedeem, uint256 bonuses) internal {
    emit Redeemed(user, amountToRedeem, bonuses);
  }
  event Staked(
    address indexed user,
    uint256 amount,
    uint256 indexed commitmentTier,
    uint256 minimum,
    bool timeLocked
  );
  function _emitStaked(address user, uint256 amount, uint256 commitmentTier, uint256 minimum, bool timeLocked) internal {
    emit Staked(user, amount, commitmentTier, minimum, timeLocked);
  }
  event Unstaked(address indexed user, uint256 amount, uint256 slashed);
  function _emitUnstaked(address user, uint256 amount, uint256 slashed) internal {
    emit Unstaked(user, amount, slashed);
  }
}
