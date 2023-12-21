// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

library ModaConstants {
	/**
	 * @dev Smart contract unique identifier, a random number
	 * @dev Should be regenerated each time smart contact source code is changed
	 *      and changes smart contract itself is to be redeployed
	 * @dev Generated using https://www.random.org/bytes/
	 */
	uint256 public constant TOKEN_UID =
		0xc8de2a18ae1c61538a5f880f5c8eb7ff85aa3996c4363a27b1c6112a190e65b4;

	/**
	 * @dev Smart contract unique identifier, a random number
	 * @dev Should be regenerated each time smart contact source code is changed
	 *      and changes smart contract itself is to be redeployed
	 * @dev Generated using https://www.random.org/bytes/
	 */
	uint256 public constant ESCROWTOKEN_UID =
		0x0a9a93ba9d22fa5ed507ff32440b8750c8951e4864438c8afc02be22ad238ebf;

	/**
	 * @dev Smart contract unique identifier, a random number
	 * @dev Should be regenerated each time smart contact source code is changed
	 *      and changes smart contract itself is to be redeployed
	 * @dev Generated using https://www.random.org/bytes/
	 */
	uint256 public constant POOL_UID =
		0x8ca5f5bb5e4f02345a019a993ce37018dd549b22e88027f4f5c1f614ef6fb3c0;

	/**
	 * @notice Upgrader is responsible for managing future versions
	 *         of the contract.
	 */
	bytes32 public constant ROLE_UPGRADER = '\x00\x0A\x00\x00';

	/**
	 * @notice Token creator is responsible for creating (minting)
	 *      tokens to an arbitrary address
	 * @dev Role ROLE_TOKEN_CREATOR allows minting tokens
	 *      (calling `mint` function)
	 */
	bytes32 public constant ROLE_TOKEN_CREATOR = '\x00\x0B\x00\x00';

	/**
	 * @notice Token stakeAsPool is responsible for stakes in Moda Pools
	 *         for an arbitrary address.
	 * @dev Role ROLE_POOL_STAKING allows creating stakes for non-Moda tokens.
	 */
	bytes32 public constant ROLE_POOL_STAKING = '\x00\x0C\x00\x00';
}
