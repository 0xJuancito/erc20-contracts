// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LibAccessControlEnumerable} from "@lib-diamond/src/access/access-control/LibAccessControlEnumerable.sol";

import {EXCLUDED_FROM_FEE_ROLE} from "../types/hamachi/HamachiRoles.sol";

import {HamachiStorage} from "../types/hamachi/HamachiStorage.sol";
import {LibHamachi20} from "./LibHamachi20.sol";
import {LibReward} from "./LibReward.sol";

import {LibUniswap} from "./LibUniswap.sol";

library LibHamachi {
  modifier lockTheSwap() {
    LibHamachi.DS().processingFees = true;
    _;
    LibHamachi.DS().processingFees = false;
  }

  bytes32 internal constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.hamachi.storage");

  function DS() internal pure returns (HamachiStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function buyFees() internal view returns (uint256, uint256) {
    return (LibHamachi.DS().fee.liquidityBuyFee, LibHamachi.DS().fee.rewardBuyFee);
  }

  function totalBuyFees() internal view returns (uint32) {
    return LibHamachi.DS().fee.rewardBuyFee + LibHamachi.DS().fee.liquidityBuyFee;
  }

  function totalSellFees() internal view returns (uint32) {
    return LibHamachi.DS().fee.rewardSellFee + LibHamachi.DS().fee.liquiditySellFee;
  }

  function isExcludedFromFee(address account) internal view returns (bool) {
    return LibAccessControlEnumerable.hasRole(EXCLUDED_FROM_FEE_ROLE, account);
  }

  function determineFee(address from, address to) internal view returns (uint32, bool) {
    if (LibHamachi.DS().lpPools[to] && !isExcludedFromFee(from) && !isExcludedFromFee(to)) {
      return (totalSellFees(), true);
    } else if (
      LibHamachi.DS().lpPools[from] && !isExcludedFromFee(to) && !LibHamachi.DS().swapRouters[to]
    ) {
      return (totalBuyFees(), false);
    }

    return (0, false);
  }

  function calculateLiquidifyAmounts(
    uint256 tokenAmount
  ) internal lockTheSwap returns (uint256, uint256) {
    (uint256 liquidityBuyFee, uint256 rewardBuyFee) = buyFees();
    uint256 totalTax = liquidityBuyFee + rewardBuyFee;
    uint256 liquidityAmount = (tokenAmount * liquidityBuyFee) / totalTax;
    uint256 liquidityTokens = liquidityAmount / 2;
    uint256 rewardAmount = (tokenAmount * rewardBuyFee) / totalTax;
    uint256 sellIntoETH = (liquidityAmount + rewardAmount) - liquidityTokens;

    return (sellIntoETH, liquidityTokens);
  }
}
