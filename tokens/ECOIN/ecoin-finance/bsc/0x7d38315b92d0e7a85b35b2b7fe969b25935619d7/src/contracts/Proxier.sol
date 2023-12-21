// SPDX-License-Identifier: Proprietary license

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EcoinProxier is Ownable, TransparentUpgradeableProxy {

  constructor(address implementation)TransparentUpgradeableProxy(implementation, msg.sender, ""){}
}