// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {
  ISynthereumRegistry
} from '../../core/registries/interfaces/IRegistry.sol';
import {ISynthereumDeployment} from '../../common/interfaces/IDeployment.sol';
import {SynthereumInterfaces} from '../../core/Constants.sol';
import {
  ISynthereumChainlinkPriceFeed
} from './interfaces/IChainlinkPriceFeed.sol';
import {ITypology} from '../../common/interfaces/ITypology.sol';
import {
  AggregatorV3Interface
} from '../../../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import {
  AccessControlEnumerable
} from '../../../@openzeppelin/contracts/access/AccessControlEnumerable.sol';

contract SynthereumChainlinkPriceFeed is
  ISynthereumChainlinkPriceFeed,
  AccessControlEnumerable
{
  bytes32 public constant MAINTAINER_ROLE = keccak256('Maintainer');

  //Describe role structure
  struct Roles {
    address admin;
    address maintainer;
  }

  //----------------------------------------
  // Storage
  //----------------------------------------

  ISynthereumFinder public immutable synthereumFinder;
  mapping(bytes32 => AggregatorV3Interface) private aggregators;

  //----------------------------------------
  // Events
  //----------------------------------------

  event SetAggregator(bytes32 indexed priceIdentifier, address aggregator);

  event RemoveAggregator(bytes32 indexed priceIdentifier);

  //----------------------------------------
  // Constructor
  //----------------------------------------
  /**
   * @notice Constructs the SynthereumChainlinkPriceFeed contract
   * @param _synthereumFinder Synthereum finder contract
   * @param roles Admin and Mainteiner roles
   */
  constructor(ISynthereumFinder _synthereumFinder, Roles memory roles) {
    synthereumFinder = _synthereumFinder;
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
    _setupRole(DEFAULT_ADMIN_ROLE, roles.admin);
    _setupRole(MAINTAINER_ROLE, roles.maintainer);
  }

  //----------------------------------------
  // Modifiers
  //----------------------------------------

  modifier onlyMaintainer() {
    require(
      hasRole(MAINTAINER_ROLE, msg.sender),
      'Sender must be the maintainer'
    );
    _;
  }

  modifier onlyPoolsOrSelfMinting() {
    if (msg.sender != tx.origin) {
      bytes32 typology =
        keccak256(abi.encodePacked(ITypology(msg.sender).typology()));
      ISynthereumRegistry registry;
      if (typology == keccak256(abi.encodePacked('POOL'))) {
        registry = ISynthereumRegistry(
          synthereumFinder.getImplementationAddress(
            SynthereumInterfaces.PoolRegistry
          )
        );
      } else if (typology == keccak256(abi.encodePacked('SELF-MINTING'))) {
        registry = ISynthereumRegistry(
          synthereumFinder.getImplementationAddress(
            SynthereumInterfaces.SelfMintingRegistry
          )
        );
      } else {
        revert('Typology not supported');
      }
      ISynthereumDeployment callingContract = ISynthereumDeployment(msg.sender);
      require(
        registry.isDeployed(
          callingContract.syntheticTokenSymbol(),
          callingContract.collateralToken(),
          callingContract.version(),
          msg.sender
        ),
        'Calling contract not registered'
      );
    }
    _;
  }

  //----------------------------------------
  // External functions
  //----------------------------------------

  /**
   * @notice Set the address of aggregator associated to a price identifier
   * @param priceIdentifier Price feed identifier
   * @param aggregator Address of chainlink proxy aggregator
   */
  function setAggregator(
    bytes32 priceIdentifier,
    AggregatorV3Interface aggregator
  ) external override onlyMaintainer {
    require(
      address(aggregators[priceIdentifier]) != address(aggregator),
      'Aggregator address is the same'
    );
    aggregators[priceIdentifier] = aggregator;
    emit SetAggregator(priceIdentifier, address(aggregator));
  }

  /**
   * @notice Remove the address of aggregator associated to a price identifier
   * @param priceIdentifier Price feed identifier
   */
  function removeAggregator(bytes32 priceIdentifier)
    external
    override
    onlyMaintainer
  {
    require(
      address(aggregators[priceIdentifier]) != address(0),
      'Price identifier does not exist'
    );
    delete aggregators[priceIdentifier];
    emit RemoveAggregator(priceIdentifier);
  }

  /**
   * @notice Get last chainlink oracle price for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @return price Oracle price
   */
  function getLatestPrice(bytes32 priceIdentifier)
    external
    view
    override
    onlyPoolsOrSelfMinting
    returns (uint256 price)
  {
    OracleData memory oracleData = _getOracleLatestRoundData(priceIdentifier);
    price = getScaledValue(oracleData.answer, oracleData.decimals);
  }

  /**
   * @notice Get last chainlink oracle data for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @return oracleData Oracle data
   */
  function getOracleLatestData(bytes32 priceIdentifier)
    external
    view
    override
    onlyPoolsOrSelfMinting
    returns (OracleData memory oracleData)
  {
    oracleData = _getOracleLatestRoundData(priceIdentifier);
  }

  /**
   * @notice Get chainlink oracle price in a given round for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @param _roundId Round Id
   * @return price Oracle price
   */
  function getRoundPrice(bytes32 priceIdentifier, uint80 _roundId)
    external
    view
    override
    onlyPoolsOrSelfMinting
    returns (uint256 price)
  {
    OracleData memory oracleData =
      _getOracleRoundData(priceIdentifier, _roundId);
    price = getScaledValue(oracleData.answer, oracleData.decimals);
  }

  /**
   * @notice Get chainlink oracle data in a given round for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @param _roundId Round Id
   * @return oracleData Oracle data
   */
  function getOracleRoundData(bytes32 priceIdentifier, uint80 _roundId)
    external
    view
    override
    onlyPoolsOrSelfMinting
    returns (OracleData memory oracleData)
  {
    oracleData = _getOracleRoundData(priceIdentifier, _roundId);
  }

  //----------------------------------------
  // Public view functions
  //----------------------------------------

  /**
   * @notice Returns the address of aggregator if exists, otherwise it reverts
   * @param priceIdentifier Price feed identifier
   * @return aggregator Aggregator associated with price identifier
   */
  function getAggregator(bytes32 priceIdentifier)
    public
    view
    override
    returns (AggregatorV3Interface aggregator)
  {
    aggregator = aggregators[priceIdentifier];
    require(
      address(aggregator) != address(0),
      'Price identifier does not exist'
    );
  }

  /**
   * @notice Return if price identifier is supported
   * @param priceIdentifier Price feed identifier
   * @return isSupported True if price is supported otherwise false
   */
  function isPriceSupported(bytes32 priceIdentifier)
    external
    view
    override
    returns (bool isSupported)
  {
    isSupported = address(aggregators[priceIdentifier]) != address(0)
      ? true
      : false;
  }

  //----------------------------------------
  // Internal view functions
  //----------------------------------------

  /**
   * @notice Get last chainlink oracle data for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @return oracleData Oracle data
   */
  function _getOracleLatestRoundData(bytes32 priceIdentifier)
    internal
    view
    returns (OracleData memory oracleData)
  {
    AggregatorV3Interface aggregator = getAggregator(priceIdentifier);
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = aggregator.latestRoundData();
    uint8 decimals = aggregator.decimals();
    oracleData = OracleData(
      roundId,
      convertPrice(answer),
      startedAt,
      updatedAt,
      answeredInRound,
      decimals
    );
  }

  /**
   * @notice Get chainlink oracle data in a given round for a given price identifier
   * @param priceIdentifier Price feed identifier
   * @param _roundId Round Id
   * @return oracleData Oracle data
   */
  function _getOracleRoundData(bytes32 priceIdentifier, uint80 _roundId)
    internal
    view
    returns (OracleData memory oracleData)
  {
    AggregatorV3Interface aggregator = getAggregator(priceIdentifier);
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = aggregator.getRoundData(_roundId);
    uint8 decimals = aggregator.decimals();
    oracleData = OracleData(
      roundId,
      convertPrice(answer),
      startedAt,
      updatedAt,
      answeredInRound,
      decimals
    );
  }

  //----------------------------------------
  // Internal pure functions
  //----------------------------------------

  /**
   * @notice Covert the price from int to uint and it reverts if negative
   * @param uncovertedPrice Price before conversion
   * @return price Price after conversion
   */

  function convertPrice(int256 uncovertedPrice)
    internal
    pure
    returns (uint256 price)
  {
    require(uncovertedPrice >= 0, 'Negative value');
    price = uint256(uncovertedPrice);
  }

  /**
   * @notice Covert the price to a integer with 18 decimals
   * @param unscaledPrice Price before conversion
   * @param decimals Number of decimals of unconverted price
   * @return price Price after conversion
   */

  function getScaledValue(uint256 unscaledPrice, uint8 decimals)
    internal
    pure
    returns (uint256 price)
  {
    price = unscaledPrice * (10**(18 - decimals));
  }
}
