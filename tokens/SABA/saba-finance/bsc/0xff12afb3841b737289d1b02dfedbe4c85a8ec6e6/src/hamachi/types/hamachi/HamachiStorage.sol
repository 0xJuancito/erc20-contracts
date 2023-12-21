// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Fee} from "../fee/Fee.sol";

struct HamachiStorage {
  uint256 numTokensToSwap;
  uint256 maxTokenPerWallet;
  mapping(address => bool) lpPools;
  mapping(address => bool) swapRouters;
  uint32 processingGas;
  bool processingFees;
  Fee fee;
  bool processRewards;
  address vestingContract;
}

uint32 constant PERCENTAGE_DENOMINATOR = 10000;
address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
