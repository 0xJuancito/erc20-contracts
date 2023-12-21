// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract WARSToken is ERC20PresetFixedSupply {
  constructor() ERC20PresetFixedSupply("MetaWars", "WARS", 15 * (10**8) * (10**18), msg.sender) {}
}