// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/// @title GoCrypto Token Contract
/// @author Eligma d.o.o.
/// @dev ERC20 Token contract 
/// @custom:experimental This is an experimental contract.
contract GoCryptoTokenContract is ERC20, AccessControlEnumerable, ERC20Pausable {
	bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

	bool private _initialised;

	constructor() ERC20("GoCrypto", "GoC") {
		_grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
	}

    // **************************************************
    // ****************** PUBLIC REGION *****************
    // **************************************************
    function burn(uint256 amount_) public virtual {
        _burn(_msgSender(), amount_);
        emit TokensBurned(_msgSender(), amount_);
    }
 
    function burnFrom(address account, uint256 amount_) public virtual {
        _spendAllowance(account, _msgSender(), amount_);
        _burn(account, amount_);
        emit TokensBurned(account, amount_);
    }

	// **************************************************
	// ****************** MODERATOR REGION **************
	// **************************************************
	function pause() public virtual onlyRole(MODERATOR_ROLE) {
		_pause();
	}

    function unpause() public virtual onlyRole(MODERATOR_ROLE) {
        _unpause();
    }

	// **************************************************
	// *************** DEFAULT_ADMIN REGION *************
	// **************************************************
	function init(
		address defaultAdminAddress_,
		address moderatorAddress_,
		address supplyDestinationAddress_,
		uint totalSupply_
	) public onlyRole(DEFAULT_ADMIN_ROLE) {
		require(!_initialised, "Contract is already initialised!");

		_grantRole(DEFAULT_ADMIN_ROLE, defaultAdminAddress_);
		_grantRole(MODERATOR_ROLE, moderatorAddress_);
		_mint(supplyDestinationAddress_, totalSupply_);
		
		_initialised = true;
		_revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
	}

	// **************************************************
	// *************** INTERNAL REGION ******************
	// **************************************************
	function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

	// **************************************************
	// ************** PUBLIC GETTERS REGION *************
	// **************************************************
	function isInitialised() public view returns (bool) {
		return _initialised;
	}

	// **************************************************
	// ****************** EVENTS REGION *****************
	// **************************************************
	event TokensMinted(address indexed from, address indexed to, uint amount);
    event TokensBurned(address indexed from, uint amount);
}
