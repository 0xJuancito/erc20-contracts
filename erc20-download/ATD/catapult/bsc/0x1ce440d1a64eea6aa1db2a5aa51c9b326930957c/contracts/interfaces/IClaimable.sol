// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/**
 * @dev Used to represent the claim and burn operations of the
 * Subchain token for the Subchain agent.
 */
interface IClaimable {
	// See {SubchainToken.claim()}
	function claim(
		uint256 amount,
		address receiver,
		bytes32 depositTx,
		bytes memory tokenSig
	) external;

	// See {SubchainToken.burn()}
	function burn(uint256 amount) external;
}
