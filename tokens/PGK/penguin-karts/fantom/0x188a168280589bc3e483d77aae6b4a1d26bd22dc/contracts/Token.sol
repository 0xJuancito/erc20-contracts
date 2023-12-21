//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

interface ILiquidityRestrictor {
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

contract Token is ERC20, Ownable {
	uint256 public totalSupply_ = 200_000_000 ether;

	constructor() ERC20('Penguin Karts', 'PGK') {
		_mint(msg.sender, totalSupply_);
	}

	IAntisnipe public antisnipe = IAntisnipe(address(0));
	ILiquidityRestrictor public liquidityRestrictor =
		ILiquidityRestrictor(address(0));

	bool public antisnipeEnabled = true;
	bool public liquidityRestrictionEnabled = true;

	event AntisnipeDisabled(uint256 timestamp, address user);
	event LiquidityRestrictionDisabled(uint256 timestamp, address user);
	event AntisnipeAddressChanged(address addr);
	event LiquidityRestrictionAddressChanged(address addr);

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		if (from == address(0) || to == address(0)) return;
		if (liquidityRestrictionEnabled && address(liquidityRestrictor) != address(0)) {
			(bool allow, string memory message) = liquidityRestrictor
				.assureLiquidityRestrictions(from, to);
			require(allow, message);
		}

		if (antisnipeEnabled && address(antisnipe) != address(0)) {
			require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
		}
	}

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
