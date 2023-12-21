// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

/**
 *
 * @dev Implementation of the ERC20 standard as defined in the EIP.
 *
 */
contract ModularToken is
	Initializable,
	ERC20CappedUpgradeable,
	AccessControlUpgradeable,
	OwnableUpgradeable
{
	/**
	 *
	 * @dev Immutable hash of MINTER_ROLE
	 *
	 */
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	/**
	 * @dev See {Initializable-initialize}
	 *
	 * Setup given name, ticker, maxSupply and initialSupply
	 *
	 * - `name` and `ticker` are provided by the proxy deployer
	 * - `initialSupply` is minted to contract deployer
	 * - `maxSupply` determines the maximum circulating supply
	 *
	 */
	function initialize(
		string memory name,
		string memory ticker,
		uint256 maxSupply,
		uint256 initialSupply
	) public initializer {
		__ERC20_init(name, ticker);
		__ERC20Capped_init(maxSupply);
		_mint(msg.sender, initialSupply);
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	/**
	 * @dev See @openzeppelin-{ERC20Mintable}
	 *
	 * Requirements:
	 *
	 * - caller must have `MINTER_ROLE` assigned
	 * - method cannot be executed by the contract itself, neither by the contract deployer
	 */

	function mint(address to, uint256 amount) external {
		require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
		_mint(to, amount);
	}
}
