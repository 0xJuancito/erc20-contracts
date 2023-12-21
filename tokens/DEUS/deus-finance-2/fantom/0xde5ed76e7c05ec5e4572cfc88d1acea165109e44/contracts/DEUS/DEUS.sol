// Be name Khoda
// Bime Abolfazl

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ========================= DEUS (DEUS) =========================
// ===============================================================
// DEUS Finance: https://github.com/DeusFinance

// Primary Author(s)
// Travis Moore: https://github.com/FortisFortuna
// Jason Huan: https://github.com/jasonhuan
// Sam Kazemian: https://github.com/samkazemian
// Vahid Gh: https://github.com/vahid-dev
// SAYaghoubnejad: https://github.com/SAYaghoubnejad

// Reviewer(s) / Contributor(s)
// Sam Sun: https://github.com/samczsun

import "../DEI/IDEI.sol";
import "../ERC20/draft-ERC20Permit.sol";
import "../Governance/AccessControl.sol";

contract DEUSToken is ERC20Permit, AccessControl {

	/* ========== STATE VARIABLES ========== */

	string public symbol;
	string public name;
	uint8 public constant decimals = 18;

	uint256 public constant genesis_supply = 100e18; // genesis supply has been minted on ETH & Polygon

	address public dei_contract_address;

	bytes32 public constant TRUSTY_ROLE = keccak256("TRUSTY_ROLE");
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	/* ========== MODIFIERS ========== */


	// Note: Used by staking contracts to mint rewards
	modifier onlyMinters() {
		require(hasRole(MINTER_ROLE, msg.sender), "DEUS: Only minters are allowed to do this operation");
		_;
	}

	modifier onlyPools() {
		require(IDEIStablecoin(dei_contract_address).dei_pools(msg.sender), "DEUS: Only dei pools are allowed to do this operation");
		_;
	}

	modifier onlyTrusty() {
		require(hasRole(TRUSTY_ROLE, msg.sender), "DEUS: You are not trusty");
		_;
	}

	/* ========== CONSTRUCTOR ========== */

	constructor(
		string memory _name,
		string memory _symbol,
		address _trusty_address
	) ERC20Permit(name) {
		require(_trusty_address != address(0), "DEUS::constructor: zero address detected");  
		name = _name;
		symbol = _symbol;
		_setupRole(DEFAULT_ADMIN_ROLE, _trusty_address);
		_setupRole(TRUSTY_ROLE, _trusty_address);
		_mint(_trusty_address, genesis_supply);
	}


	/* ========== RESTRICTED FUNCTIONS ========== */

	function setNameAndSymbol(string memory _name, string memory _symbol) external onlyTrusty {
		name = _name;
		symbol = _symbol;

		emit NameAndSymbolSet(name, symbol);
	}

	function setDEIAddress(address _dei_contract_address)
		external
		onlyTrusty
	{
		require(_dei_contract_address != address(0), "DEUS::setDEIAddress: Zero address detected");

		dei_contract_address = _dei_contract_address;

		emit DEIAddressSet(dei_contract_address);
	}

	// Note: Used by staking contracts to mint rewards
	function mint(address to, uint256 amount) public onlyMinters {
		_mint(to, amount);
	}

	// This function is what other dei pools will call to mint new DEUS (similar to the DEI mint) and staking contracts can call this function too.
	function pool_mint(address m_address, uint256 m_amount) external onlyPools {
		super._mint(m_address, m_amount);
		emit DEUSMinted(address(this), m_address, m_amount);
	}

	// This function is what other dei pools will call to burn DEUS
	function pool_burn_from(address b_address, uint256 b_amount) external onlyPools {
		super._burnFrom(b_address, b_amount);
		emit DEUSBurned(b_address, address(this), b_amount);
	}

	/* ========== EVENTS ========== */
	event DEUSBurned(address indexed from, address indexed to, uint256 amount);
	event DEUSMinted(address indexed from, address indexed to, uint256 amount);
	event DEIAddressSet(address addr);
	event NameAndSymbolSet(string name, string symbol);
}

//Dar panah khoda