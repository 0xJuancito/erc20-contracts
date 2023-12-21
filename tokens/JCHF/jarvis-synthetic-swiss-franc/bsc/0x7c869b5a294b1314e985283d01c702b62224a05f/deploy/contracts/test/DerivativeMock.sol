// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ISynthereumFinder} from '../core/interfaces/IFinder.sol';
import {
  FixedPoint
} from '../../@uma/core/contracts/common/implementation/FixedPoint.sol';

contract DerivativeMock {
  IERC20 private collateral;
  IERC20 private token;
  bytes32 private priceFeedIdentifier;

  constructor(
    IERC20 _collateral,
    IERC20 _token,
    bytes32 _priceFeedIdentifier
  ) {
    collateral = _collateral;
    token = _token;
    priceFeedIdentifier = _priceFeedIdentifier;
  }

  function collateralCurrency() external view returns (IERC20) {
    return collateral;
  }

  function tokenCurrency() external view returns (IERC20 syntheticCurrency) {
    return token;
  }

  function priceIdentifier() external view returns (bytes32 priceId) {
    priceId = priceFeedIdentifier;
  }
}
