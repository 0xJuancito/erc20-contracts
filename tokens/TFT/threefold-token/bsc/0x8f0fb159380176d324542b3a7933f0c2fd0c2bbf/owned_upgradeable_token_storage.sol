pragma solidity >=0.7.0 <0.9.0;

import "./token_storage.sol";
import "./upgradeable.sol";

contract OwnedUpgradeableTokenStorage is TokenStorage, Upgradeable {}