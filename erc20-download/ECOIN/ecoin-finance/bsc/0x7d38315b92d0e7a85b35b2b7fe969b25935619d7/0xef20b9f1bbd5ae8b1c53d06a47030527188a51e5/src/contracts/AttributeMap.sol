// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./Authorized.sol";

contract AttributeMap is Authorized {

  mapping (address => uint) internal _attributeMap;

  // ------------- Public Views -------------
  function isExemptFee(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 0); }
  function isExemptFeeReceiver(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 1); }
  function isExemptTxLimit(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 2); }
  function isExemptAmountLimit(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 3); }
  function isExemptStaker(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 4); }
  function isExemptDistributionMaker(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 5); }
  function isExemptOperatePausedToken(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 6); }
  function isExemptInnerTrade(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 7); }
  function isSpecialFeeWallet(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 8); }
  function isSpecialFeeWalletReceiver(address target) public view returns(bool) { return checkMapAttribute(_attributeMap[target], 9); }

  // ------------- Internal PURE GET Functions -------------
  function checkMapAttribute(uint mapValue, uint8 shift) internal pure returns(bool) { return mapValue >> shift & 1 == 1; }
  function isExemptFee(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 0); }
  function isExemptFeeReceiver(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 1); }
  function isExemptTxLimit(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 2); }
  function isExemptAmountLimit(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 3); }
  function isExemptStaker(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 4); }
  function isExemptDistributionMaker(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 5); }
  function isExemptOperatePausedToken(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 6); }
  function isExemptInnerTrade(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 7); }
  function isSpecialFeeWallet(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 8); }
  function isSpecialFeeWalletReceiver(uint mapValue) internal pure returns(bool) { return checkMapAttribute(mapValue, 9); }

  // ------------- Internal PURE SET Functions -------------
  function setMapAttribute(uint mapValue, uint8 shift, bool include) internal pure returns(uint) { return include ? applyMapAttribute(mapValue, shift) : removeMapAttribute(mapValue, shift); }
  function applyMapAttribute(uint mapValue, uint8 shift) internal pure returns(uint) { return 1 << shift | mapValue; }
  function removeMapAttribute(uint mapValue, uint8 shift) internal pure returns(uint) { return 1 << shift ^ type(uint).max & mapValue; }

  // ------------- Public Internal SET Functions -------------
  function setExemptFee(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 0, operation); }
  function setExemptFeeReceiver(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 1, operation); }
  function setExemptTxLimit(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 2, operation); }
  function setExemptAmountLimit(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 3, operation); }
  function setExemptStaker(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 4, operation); }
  function setExemptDistributionMaker(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 5, operation); }
  function setExemptOperatePausedToken(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 6, operation); }
  function setExemptInnerTrade(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 7, operation); }
  function setSpecialFeeWallet(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 8, operation); }
  function setSpecialFeeWalletReceiver(uint mapValue, bool operation) internal pure returns(uint) { return setMapAttribute(mapValue, 9, operation); }
  

  // ------------- Public Authorized SET Functions -------------
  function setExemptFee(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptFee(_attributeMap[target], operation); }
  function setExemptFeeReceiver(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptFeeReceiver(_attributeMap[target], operation); }
  function setExemptTxLimit(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptTxLimit(_attributeMap[target], operation); }
  function setExemptAmountLimit(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptAmountLimit(_attributeMap[target], operation); }
  function setExemptStaker(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptStaker(_attributeMap[target], operation); }
  function setExemptDistributionMaker(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptDistributionMaker(_attributeMap[target], operation); }
  function setExemptOperatePausedToken(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptOperatePausedToken(_attributeMap[target], operation); }
  function setExemptInnerTrade(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setExemptInnerTrade(_attributeMap[target], operation); }
  function setSpecialFeeWallet(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setSpecialFeeWallet(_attributeMap[target], operation); }
  function setSpecialFeeWalletReceiver(address target, bool operation) public isAuthorized(2) { _attributeMap[target] = setSpecialFeeWalletReceiver(_attributeMap[target], operation); }
}
