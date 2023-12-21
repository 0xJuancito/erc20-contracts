pragma solidity ^0.5.0;

import "./UpgradeabilityProxy.sol";
import "./TokenStorage.sol";
import "./OwnershipStorage.sol";

contract UpgradeableTokenStorage is UpgradeabilityProxy, TokenStorage, OwnershipStorage {}