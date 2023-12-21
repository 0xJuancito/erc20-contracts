// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Fee} from "../fee/Fee.sol";

struct UniswapStorage {
  address liquidityWallet;
  address defaultRouter;
}
