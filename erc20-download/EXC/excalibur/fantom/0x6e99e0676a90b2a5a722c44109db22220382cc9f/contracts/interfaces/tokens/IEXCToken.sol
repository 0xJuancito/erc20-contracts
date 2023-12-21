// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "./IRegularToken.sol";

interface IEXCToken is IRegularToken {
  function autoBurnRate() external view returns (uint256);
}
