// SPDX-License-Identifier: UNLICENSED
// v1.21
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

interface ILiquidityRestrictor {
	function assureByAgent(
		address token,
		address from,
		address to
	) external returns (bool allow, string memory message);

	function assureLiquidityRestrictions(address from, address to)
		external
		returns (bool allow, string memory message);
}

interface IAntisnipe {
	function assureCanTransfer(
		address sender,
		address from,
		address to,
		uint256 amount
	) external returns (bool response);
}

contract SCRLToken is ERC20, Ownable, ERC20Burnable {
	constructor() ERC20('Wizarre Scroll', 'SCRL') {
		uint256 initialSupply = 10000000000000000000000000000; //10b
		address owner = msg.sender;
		_mint(owner, initialSupply);
		transferOwnership(owner);
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20) {
		if (from == address(0) || to == address(0)) return;
		if (liquidityRestrictionEnabled && address(liquidityRestrictor) != address(0)) {
			(bool allow, string memory message) = liquidityRestrictor
				.assureLiquidityRestrictions(from, to);
			require(allow, message);
		}

		if (antisnipeEnabled && address(antisnipe) != address(0)) {
			require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
		}

		super._beforeTokenTransfer(from, to, amount);
	}

	IAntisnipe public antisnipe = IAntisnipe(0xbccE75E1b2C953C83B462F80865f408112CE29A2);
	ILiquidityRestrictor public liquidityRestrictor =
		ILiquidityRestrictor(0xeD1261C063563Ff916d7b1689Ac7Ef68177867F2);

	bool public antisnipeEnabled = true;
	bool public liquidityRestrictionEnabled = true;

	event AntisnipeDisabled(uint256 timestamp, address user);
	event LiquidityRestrictionDisabled(uint256 timestamp, address user);
	event AntisnipeAddressChanged(address addr);
	event LiquidityRestrictionAddressChanged(address addr);

	function setAntisnipeDisable() external onlyOwner {
		require(antisnipeEnabled);
		antisnipeEnabled = false;
		emit AntisnipeDisabled(block.timestamp, msg.sender);
	}

	function setLiquidityRestrictorDisable() external onlyOwner {
		require(liquidityRestrictionEnabled);
		liquidityRestrictionEnabled = false;
		emit LiquidityRestrictionDisabled(block.timestamp, msg.sender);
	}

	function setAntisnipeAddress(address addr) external onlyOwner {
		antisnipe = IAntisnipe(addr);
		emit AntisnipeAddressChanged(addr);
	}

	function setLiquidityRestrictionAddress(address addr) external onlyOwner {
		liquidityRestrictor = ILiquidityRestrictor(addr);
		emit LiquidityRestrictionAddressChanged(addr);
	}
}
