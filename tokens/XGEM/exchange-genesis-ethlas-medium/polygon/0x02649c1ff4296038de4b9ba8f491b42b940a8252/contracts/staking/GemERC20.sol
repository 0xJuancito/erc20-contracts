// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract GemERC20 is ERC20PresetFixedSupply {
	constructor(uint256 initialSupply) ERC20PresetFixedSupply("Exchange Genesis Ethlas Medium", "XGEM", initialSupply,  msg.sender){}
}