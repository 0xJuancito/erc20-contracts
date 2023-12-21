// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/i_Antisnipe.sol";

contract Gov_Token is Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
	IAntisnipe public antisnipe;
	bool public antisnipeDisable;
	uint256[50] __gap;

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize() public initializer {
		__ERC20_init("Crypto Asset Governance Alliance", "CAGA");
		__ERC20Permit_init("Crypto Asset Governance Alliance");
		__Ownable_init();
		__UUPSUpgradeable_init();

		// 100 billion
		_mint(msg.sender, 100000000000 * 10 ** decimals());
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

	function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
		if (from == address(0) || to == address(0)) return;
		if (!antisnipeDisable && address(antisnipe) != address(0)) antisnipe.assureCanTransfer(msg.sender, from, to, amount);
	}

	function setAntisnipeDisable() external onlyOwner {
		require(!antisnipeDisable);
		antisnipeDisable = true;
	}

	function setAntisnipeAddress(address addr) external onlyOwner {
		antisnipe = IAntisnipe(addr);
	}
}
