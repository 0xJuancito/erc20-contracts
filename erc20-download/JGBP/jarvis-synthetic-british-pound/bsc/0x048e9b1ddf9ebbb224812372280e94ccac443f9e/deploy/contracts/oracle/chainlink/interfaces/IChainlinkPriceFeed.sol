// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {
  AggregatorV3Interface
} from '../../../../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import {ISynthereumPriceFeed} from '../../common/interfaces/IPriceFeed.sol';

interface ISynthereumChainlinkPriceFeed is ISynthereumPriceFeed {
  struct OracleData {
    uint80 roundId;
    uint256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
    uint8 decimals;
  }

  /**
   * @notice Set the address of aggregator associated to a pricee identifier
   * @param priceIdentifier Price feed identifier
   * @param aggregator Address of chainlink proxy aggregator
   */
  function setAggregator(
    bytes32 priceIdentifier,
    AggregatorV3Interface aggregator
  ) external;

  /**
   * @notice Remove the address of aggregator associated to a price identifier
   * @param priceIdentifier Price feed identifier
   */
  function removeAggregator(bytes32 priceIdentifier) external;

  /**
   * @notice Returns the address of aggregator if exists, otherwise it reverts
   * @param priceIdentifier Price feed identifier
   * @return aggregator Aggregator associated with price identifier
   */
  function getAggregator(bytes32 priceIdentifier)
    external
    view
    returns (AggregatorV3Interface aggregator);

  /**
   * @notice Get last chainlink oracle data for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @return oracleData Oracle data
   */
  function getOracleLatestData(bytes32 priceIdentifier)
    external
    view
    returns (OracleData memory oracleData);

  /**
   * @notice Get chainlink oracle price in a given round for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @param _roundId Round Id
   * @return price Oracle price
   */
  function getRoundPrice(bytes32 priceIdentifier, uint80 _roundId)
    external
    view
    returns (uint256 price);

  /**
   * @notice Get chainlink oracle data in a given round for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @param _roundId Round Id
   * @return oracleData Oracle data
   */
  function getOracleRoundData(bytes32 priceIdentifier, uint80 _roundId)
    external
    view
    returns (OracleData memory oracleData);
}
