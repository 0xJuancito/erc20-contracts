// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (metatx/ERC2771Context.sol)

pragma solidity ^0.8.0;

import {SynthereumLiquidityPool} from '../synthereum-pool/v5/LiquidityPool.sol';

contract MockContext is SynthereumLiquidityPool {
  constructor(SynthereumLiquidityPool.ConstructorParams memory params)
    SynthereumLiquidityPool(params)
  {}

  function test() public view returns (address, bytes memory) {
    return (_msgSender(), _msgData());
  }
}
