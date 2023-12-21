// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {
  ISynthereumChainlinkPriceFeed
} from '../oracle/chainlink/interfaces/IChainlinkPriceFeed.sol';

contract WrongTypology {
  string public constant typology = 'WRONG';
  ISynthereumChainlinkPriceFeed public priceFeed;

  constructor(address _priceFeed) {
    priceFeed = ISynthereumChainlinkPriceFeed(_priceFeed);
  }

  function getPrice(bytes32 identifier) external view returns (uint256 price) {
    price = priceFeed.getLatestPrice(identifier);
  }
}
