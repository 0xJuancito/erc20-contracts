// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract TTK is ERC20PresetFixedSupply {
  constructor() ERC20PresetFixedSupply("The Three Kingdoms", "TTK", 1 * (10**9) * (10**18), msg.sender) {}
}