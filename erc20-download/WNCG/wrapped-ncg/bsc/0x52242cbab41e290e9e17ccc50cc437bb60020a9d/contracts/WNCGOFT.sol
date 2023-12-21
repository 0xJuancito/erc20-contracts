// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/fee/OFTWithFee.sol";

contract WNCGOFT is OFTWithFee {
  constructor(uint8 _sharedDecimals, address _lzEndpoint)
    OFTWithFee("WrappedNCG", "WNCG", _sharedDecimals, _lzEndpoint) {
  }
}
