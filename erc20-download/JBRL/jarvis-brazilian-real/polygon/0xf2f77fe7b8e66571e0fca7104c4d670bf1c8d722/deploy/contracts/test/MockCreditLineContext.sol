// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (metatx/ERC2771Context.sol)

pragma solidity 0.8.9;

import {CreditLine} from '../self-minting/v2/CreditLine.sol';

contract MockCreditLineContext is CreditLine {
  constructor(CreditLine.PositionManagerParams memory params)
    CreditLine(params)
  {}

  function test() public view returns (address, bytes memory) {
    return (_msgSender(), _msgData());
  }
}
