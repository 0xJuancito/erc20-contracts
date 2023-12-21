// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AliERC20v2.sol";

/**
 * @title Artificial Liquid Intelligence ERC20 Token (With Polygon Support)
 *
 * @notice Polygon extension contract ads the functions required to bridge original
 *      ALI token on Ethereum L1; these are mint and burn functions executed
 *      when the tokens are deposited from from Ethereum L1 into Polygon L2 (mint),
 *      and when the tokens are withdrawn back from Polygon L2 into Ethereum L1 (burn).
 *
 * @notice Read more:
 *      https://docs.polygon.technology/docs/develop/ethereum-polygon/mintable-assets
 */
contract PolygonAliERC20v2 is AliERC20v2Base {

	/**
	 * @dev Constructs/deploys Polygon ALI instance,
	 *      assigns initial token supply to the address specified
	 */
	constructor() AliERC20v2Base(address(0), 0) {}

	/**
	 * @notice Executed by ChildChainManager when token is deposited on the root chain
	 *
	 * @dev Executable only by ChildChainManager which should be given the minting
	 *      permission as part of the smart contract deployment process;
	 *      handles the deposit by minting the required amount for user
	 *
	 * @param user user address for whom deposit is being done
	 * @param depositData abi encoded amount
	 */
	function deposit(address user, bytes calldata depositData) external {
		// extract the amount value to mint from the calldata
		uint256 amount = abi.decode(depositData, (uint256));

		// delegate to `mint`
		mint(user, amount);
	}

	/**
	 * @notice Executed by the tokens owner when they want to withdraw tokens back to the root chain
	 *
	 * @dev Burns user's tokens;
	 *      this transaction will be verified when exiting on the root chain
	 *
	 * @param amount amount of tokens to withdraw
	 */
	function withdraw(uint256 amount) external {
		// delegate to the `burn` function
		burn(msg.sender, amount);
	}
}
