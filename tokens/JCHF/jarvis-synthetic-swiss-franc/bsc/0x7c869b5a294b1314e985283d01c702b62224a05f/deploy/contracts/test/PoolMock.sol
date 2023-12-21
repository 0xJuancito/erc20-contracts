// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract PoolMock {
  uint8 private poolVersion;
  IERC20 private collateralCurrency;
  string private tokenSymbol;
  IERC20 private token;

  constructor(
    uint8 _version,
    IERC20 _collateralToken,
    string memory _syntheticTokenSymbol,
    IERC20 _syntheticToken
  ) {
    poolVersion = _version;
    collateralCurrency = _collateralToken;
    tokenSymbol = _syntheticTokenSymbol;
    token = _syntheticToken;
  }

  function version() external view returns (uint8) {
    return poolVersion;
  }

  function collateralToken() external view returns (IERC20) {
    return collateralCurrency;
  }

  function syntheticTokenSymbol() external view returns (string memory) {
    return tokenSymbol;
  }

  function syntheticToken() external view returns (IERC20) {
    return token;
  }
}
