// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LibDiamond} from "@lib-diamond/src/diamond/LibDiamond.sol";
import {LibAccessControlEnumerable} from "@lib-diamond/src/access/access-control/LibAccessControlEnumerable.sol";

import {EXCLUDED_FROM_REWARD_ROLE} from "../types/hamachi/HamachiRoles.sol";

import {RewardStorage, RewardToken, Map, MAGNITUDE} from "../types/reward/RewardStorage.sol";
import {LibUniswap} from "./LibUniswap.sol";
import {LibHamachi} from "./LibHamachi.sol";
import {IVestingSchedule} from "../interfaces/IVestingSchedule.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

error InvalidClaimTime();
error NoSupply();
error NullAddress();

library LibReward {
  event UpdateRewardToken(address token);
  event RewardProcessed(address indexed owner, uint256 value, address indexed token);

  bytes32 internal constant REWARD_STORAGE_POSITION = keccak256("diamond.standard.reward.storage");

  function DS() internal pure returns (RewardStorage storage rs) {
    bytes32 position = REWARD_STORAGE_POSITION;
    assembly {
      rs.slot := position
    }
  }

  // ==================== DividendPayingToken ==================== //

  /// @return dividends The amount of rewards that `_owner` has withdrawn
  function withdrawnDividendOf(address _owner) internal view returns (uint256 dividends) {
    return LibReward.DS().withdrawnReward[_owner];
  }

  /// @return accumulated The total accumulated rewards for a address
  function accumulativeDividendOf(address _owner) internal view returns (uint256 accumulated) {
    return
      SafeCast.toUint256(
        SafeCast.toInt256(LibReward.DS().magnifiedRewardPerShare * rewardBalanceOf(_owner)) +
          LibReward.DS().magnifiedReward[_owner]
      ) / MAGNITUDE;
  }

  /// @return withdrawable The total withdrawable rewards for a address
  function withdrawableDividendOf(address _owner) internal view returns (uint256 withdrawable) {
    return accumulativeDividendOf(_owner) - LibReward.DS().withdrawnReward[_owner];
  }

  // ==================== Views ==================== //

  function rewardBalanceOf(address account) internal view returns (uint256) {
    return LibReward.DS().rewardBalances[account];
  }

  function getIndexOfKey(address key) internal view returns (int256 index) {
    return
      LibReward.DS().rewardHolders.inserted[key]
        ? int256(LibReward.DS().rewardHolders.indexOf[key])
        : -1;
  }

  // ==================== Management ==================== //

  /// @notice Adds incoming funds to the rewards per share
  function accrueReward(uint256 amount) internal {
    uint256 rewardSupply = LibReward.DS().totalRewardSupply;
    if (rewardSupply <= 0) revert NoSupply();

    if (amount > 0) {
      LibReward.DS().magnifiedRewardPerShare += (amount * MAGNITUDE) / rewardSupply;
      LibReward.DS().totalAccruedReward += amount;
    }
  }

  function setRewardToken(
    address token,
    address router,
    address[] memory path,
    bool _useV3,
    bytes memory pathV3
  ) internal {
    if (token == address(0)) revert NullAddress();
    RewardToken storage rewardToken = DS().rewardToken;

    rewardToken.token = token;
    rewardToken.router = router;
    rewardToken.path = path;
    rewardToken.useV3 = _useV3;
    rewardToken.pathV3 = pathV3;

    emit UpdateRewardToken(token);
  }

  function setGoHamToken(
    address token,
    address router
  ) internal {
    if (token == address(0)) revert NullAddress();
    RewardToken storage hamiToken = DS().goHam;

    hamiToken.token = token;
    hamiToken.router = router;
  }

  // This function uses a set amount of gas to process rewards for as many wallets as it can
  function processRewards() internal {
    uint256 gas = LibHamachi.DS().processingGas;
    if (gas == 0) return;

    uint256 numHolders = LibReward.DS().rewardHolders.keys.length;
    uint256 _lastProcessedIndex = LibReward.DS().lastProcessedIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;

    while (gasUsed < gas && iterations < numHolders) {
      ++iterations;
      if (++_lastProcessedIndex >= LibReward.DS().rewardHolders.keys.length) {
        _lastProcessedIndex = 0;
      }
      address account = LibReward.DS().rewardHolders.keys[_lastProcessedIndex];

      if (LibReward.DS().manualClaim[account]) continue;

      if (!_canAutoClaim(LibReward.DS().claimTimes[account])) continue;
      _processAccount(account, false, 0);

      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) {
        gasUsed += gasLeft - newGasLeft;
      }
      gasLeft = newGasLeft;
    }
    LibReward.DS().lastProcessedIndex = _lastProcessedIndex;
  }

  /// @param newBalance The new balance to set for the account.
  function setRewardBalance(address account, uint256 newBalance) internal {
    if (LibAccessControlEnumerable.hasRole(EXCLUDED_FROM_REWARD_ROLE, account)) return;

    if (LibHamachi.DS().vestingContract != address(0)) {
      (, , , , , , uint256 amountTotal, uint256 released) = IVestingSchedule(
        LibHamachi.DS().vestingContract
      ).getVestingSchedule(account);
      if (amountTotal > 0) {
        newBalance += amountTotal - released;
      }
    }

    if (newBalance >= LibReward.DS().minRewardBalance) {
      _setBalance(account, newBalance);
      _set(account, newBalance);
    } else {
      _setBalance(account, 0);
      _remove(account);
      _processAccount(account, false, 0);
    }
  }

  function _canAutoClaim(uint256 lastClaimTime) internal view returns (bool) {
    return
      lastClaimTime > block.timestamp
        ? false
        : block.timestamp - lastClaimTime >= LibReward.DS().claimTimeout;
  }

  function _processAccount(address _owner, bool _goHami, uint256 _expectedOutput) internal {
    uint256 _withdrawableReward = withdrawableDividendOf(_owner);
    if (_withdrawableReward <= 0) return;

    LibReward.DS().withdrawnReward[_owner] += _withdrawableReward;
    LibReward.DS().claimTimes[_owner] = block.timestamp;

    RewardToken memory rewardToken = _goHami ? LibReward.DS().goHam : LibReward.DS().rewardToken;

    bool success = false;
    if (rewardToken.useV3 && !_goHami) {
      success = LibUniswap.swapUsingV3(rewardToken, _withdrawableReward, _owner, _expectedOutput);
    } else {
      success = LibUniswap.swapUsingV2(rewardToken, _withdrawableReward, _owner, _expectedOutput);
    }
    if (success) {
      emit RewardProcessed(_owner, _withdrawableReward, rewardToken.token);
    } else {
      LibReward.DS().withdrawnReward[_owner] -= _withdrawableReward;
    }
  }

  function _setBalance(address _owner, uint256 _newBalance) internal {
    uint256 currentBalance = rewardBalanceOf(_owner);
    LibReward.DS().totalRewardSupply =
      LibReward.DS().totalRewardSupply +
      _newBalance -
      currentBalance;

    if (_newBalance > currentBalance) {
      _add(_owner, _newBalance - currentBalance);
    } else if (_newBalance < currentBalance) {
      _subtract(_owner, currentBalance - _newBalance);
    } else {
      return;
    }
  }

  function _set(address key, uint256 val) internal {
    Map storage rewardHolders = LibReward.DS().rewardHolders;
    if (rewardHolders.inserted[key]) {
      rewardHolders.values[key] = val;
    } else {
      rewardHolders.inserted[key] = true;
      rewardHolders.values[key] = val;
      rewardHolders.indexOf[key] = rewardHolders.keys.length;
      rewardHolders.keys.push(key);
    }
  }

  function _remove(address key) internal {
    Map storage rewardHolders = LibReward.DS().rewardHolders;
    if (!rewardHolders.inserted[key]) {
      return;
    }

    delete rewardHolders.inserted[key];
    delete rewardHolders.values[key];

    uint256 index = rewardHolders.indexOf[key];
    uint256 lastIndex = rewardHolders.keys.length - 1;
    address lastKey = rewardHolders.keys[lastIndex];

    rewardHolders.indexOf[lastKey] = index;
    delete rewardHolders.indexOf[key];

    rewardHolders.keys[index] = lastKey;
    rewardHolders.keys.pop();
  }

  function _add(address _owner, uint256 value) internal {
    LibReward.DS().magnifiedReward[_owner] -= SafeCast.toInt256(
      LibReward.DS().magnifiedRewardPerShare * value
    );
    LibReward.DS().rewardBalances[_owner] += value;
  }

  function _subtract(address _owner, uint256 value) internal {
    LibReward.DS().magnifiedReward[_owner] += SafeCast.toInt256(
      LibReward.DS().magnifiedRewardPerShare * value
    );
    LibReward.DS().rewardBalances[_owner] -= value;
  }
}
