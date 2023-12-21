// contracts/BNKToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BNKToken is Initializable, ERC20PresetMinterPauserUpgradeable, UUPSUpgradeable, OwnableUpgradeable {

	function initialize(string memory name, string memory symbol) public override initializer {
		__ERC20PresetMinterPauser_init(name, symbol);
		__Ownable_init();
		__UUPSUpgradeable_init();
	}

	function decimals() public view virtual override returns (uint8) {
		return 8;
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}

	uint256[50] private __gap;
}