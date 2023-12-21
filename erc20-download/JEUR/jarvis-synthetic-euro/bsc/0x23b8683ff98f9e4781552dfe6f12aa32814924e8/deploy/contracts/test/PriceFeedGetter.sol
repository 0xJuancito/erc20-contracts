// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {
  ISynthereumChainlinkPriceFeed
} from '../oracle/chainlink/interfaces/IChainlinkPriceFeed.sol';
import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract PriceFeedGetter {
  string public constant typology = 'POOL';
  ISynthereumChainlinkPriceFeed public priceFeed;

  string private symbol;
  IERC20 private token;
  uint8 private poolVersion;

  constructor(
    address _priceFeed,
    string memory _symbol,
    IERC20 _token,
    uint8 _poolVersion
  ) {
    priceFeed = ISynthereumChainlinkPriceFeed(_priceFeed);
    symbol = _symbol;
    token = _token;
    poolVersion = _poolVersion;
  }

  function getPrice(bytes32 identifier) external view returns (uint256 price) {
    price = priceFeed.getLatestPrice(identifier);
  }

  function syntheticTokenSymbol() external view returns (string memory) {
    return symbol;
  }

  function collateralToken() external view returns (IERC20) {
    return token;
  }

  function version() external view returns (uint8) {
    return poolVersion;
  }
}
