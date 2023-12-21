// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./interfaces/IClaimable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Implementation of a contract that acts a token in a non-main chain
 *
 * This is a ERC20 token implementation with one slight difference:
 * It mints a given amount for a user who deposited this amount in the ETH chain.
 * The amount is burned when a user transfers value back to the main chain.
 * The mint operation is checked by Signer, the signature is validated by the
 * Bridge Service making sure that the deposit has been made in another chain.
 *
 * HINT: you can set signer to address(0) to pause claims.
 *
 * See {SubchainBridgeAgent} and {claim()} for more information.
 */
contract SubchainToken is ERC20, Ownable, IClaimable {
	using ECDSA for bytes32;

	// Remembers used signatures to avoid reuse and re-entry
	mapping(bytes32 => bool) internal signatureUsed;
	// Signer that is used to validate {claim()} operations
	address internal signer;

	// Emitted when amount of this token has been minted
	event Claim(
		bytes32 indexed depositTx,
		address indexed receiver,
		uint256 amount
	);

	// Emitted when a token being deposited back and the amount is burned
	event Burn(address indexed wallet, uint256 amount);

	// Emitted when the signer is changed
	event SetSigner(
		address indexed changedBy,
		address indexed previousSigner,
		address indexed newSigner
	);

	/**
	 * @dev Initializes the subchain token contract
	 *
	 * @param name_ name of a subchain token contract, see {IERC20.name()}
	 * @param symbol_ symbol name of a subchain token contract, see {IERC20.symbol()}
	 * @param owner_ owner who can change signer
	 * @param signer_ signer that is used to validate {claim()} operations
	 */
	constructor(
		string memory name_,
		string memory symbol_,
		address owner_,
		address signer_
	) ERC20(name_, symbol_) {
		transferOwnership(owner_);
		signer = signer_;
	}

	/**
	 * @notice sets a new signer
	 *
	 * Emits {SetSigner}
	 *
	 * HINT: set signer to address(0) to pause claims.
	 *
	 * Requirements
	 * - Caller must be token owner
	 */
	function setSigner(address newSigner) external onlyOwner {
		emit SetSigner(_msgSender(), signer, newSigner);
		signer = newSigner;
	}

	/**
	 * @notice Returns current token signer
	 * @return address
	 */
	function getSigner() external view returns (address) {
		return signer;
	}

	/**
	 * @notice Mints the amount for a given {receiver}
	 *
	 * @param amount wei amount to be minted
	 * @param receiver walled to be minted to
	 * @param depositHash hash of the deposit transaction in another chain
	 * @param tokenSig signature of the {signer} that validates the deposit
	 *
	 * Emits {Claim}
	 *
	 * The {signer} signature is checked in order to validate the
	 * amount about to claim is being deposited in another chain.
	 *
	 * Requirements:
	 * - Valid {tokenSig} obtained from the Bridge Srvice, cannot be reused.
	 * - {signer} currently set for the token cannot be empty address(0).
	 */
	function claim(
		uint256 amount,
		address receiver,
		bytes32 depositHash,
		bytes memory tokenSig
	) external override {
		bytes32 sigHash = keccak256(tokenSig);
		require(!signatureUsed[sigHash], "cannot reuse signature");
		signatureUsed[sigHash] = true;

		// Can set signer to address(0) to pause claims
		require(signer != address(0), "empty signer");

		// check signature
		bytes32 messageHash = keccak256(
			abi.encode(
				msg.sender, // calling contract
				depositHash,
				address(this),
				block.chainid,
				receiver,
				amount
			)
		);
		bytes32 ethHash = messageHash.toEthSignedMessageHash();
		require(ethHash.recover(tokenSig) == signer, "invalid token signature");

		emit Claim(depositHash, receiver, amount);
		_mint(receiver, amount);
	}

	/**
	 * @notice Burns the amount for a caller
	 *
	 * @param amount wei amount to be burned
	 *
	 * Emits {Burn}
	 *
	 * Requirements:
	 * - Caller should have enough balance to burn the given amount
	 */
	function burn(uint256 amount) external override {
		emit Burn(_msgSender(), amount);
		_burn(_msgSender(), amount);
	}
}
