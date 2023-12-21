// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ModularToken.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract ModularTokenV2 is ModularToken, ERC20PermitUpgradeable {
	function initializeV2()
		public
		reinitializer(2)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		__ERC20Permit_init("Modular");
		__Ownable_init();
	}

	/**
	 * @dev See {ERC20-_mint}.
	 */
	function _mint(
		address account,
		uint256 amount
	) internal virtual override(ERC20CappedUpgradeable, ERC20Upgradeable) {
		require(
			ERC20Upgradeable.totalSupply() + amount <= cap(),
			"ERC20Capped: cap exceeded"
		);
		super._mint(account, amount);
	}
}
