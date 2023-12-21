// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {TestnetERC20} from './TestnetERC20.sol';

contract TestnetSelfMintingERC20 is TestnetERC20 {
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) TestnetERC20(_name, _symbol, _decimals) {}
}
