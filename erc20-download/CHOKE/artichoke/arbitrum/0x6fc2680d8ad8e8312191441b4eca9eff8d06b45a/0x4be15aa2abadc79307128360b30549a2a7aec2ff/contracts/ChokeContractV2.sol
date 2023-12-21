// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import './ChokeContract.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol';

contract ChokeTokenV2 is ChokeToken, ERC20BurnableUpgradeable {
	function initializeV2()
		public
		reinitializer(2)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		__ERC20Burnable_init();
	}

	/**
	 * @dev See {ERC20-_mint}.
	 */
	function _mint(
		address account,
		uint256 amount
	) internal virtual override(ChokeToken, ERC20Upgradeable) {
		require(
			ERC20Upgradeable.totalSupply() + amount <= cap(),
			'ERC20Capped: cap exceeded'
		);
		super._mint(account, amount);
	}
}
