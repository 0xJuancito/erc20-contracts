// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

contract MockOnChainOracle {
  mapping(bytes32 => uint256) idToPrice;

  uint8 decimals;

  constructor(uint8 _decimals) {
    decimals = _decimals;
  }

  function getLatestPrice(bytes32 identifier)
    external
    view
    returns (uint256 price)
  {
    price = idToPrice[identifier];
    price = price * (10**(18 - decimals));
  }

  function setPrice(bytes32 identifier, uint256 price) external {
    idToPrice[identifier] = price;
  }

  function isPriceSupported(bytes32 identifier) external view returns (bool) {
    return idToPrice[identifier] > 0;
  }
}
