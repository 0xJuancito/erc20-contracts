// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  ISynthereumChainlinkPriceFeed
} from '../oracle/chainlink/interfaces/IChainlinkPriceFeed.sol';

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

  function getRate(address priceFeed, bytes32 identifier)
    external
    view
    returns (uint256)
  {
    return ISynthereumChainlinkPriceFeed(priceFeed).getLatestPrice(identifier);
  }
}
