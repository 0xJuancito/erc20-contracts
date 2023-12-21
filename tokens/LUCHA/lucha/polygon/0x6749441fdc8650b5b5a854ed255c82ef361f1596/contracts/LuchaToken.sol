// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LuchaToken is ERC20, AccessControl {
	address public fxManager;
	address public connectedToken;

	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

	constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
		_mint(to, amount);
	}

	function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
		_burn(from, amount);
	}

	function updateFxManager(address newFxManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(newFxManager != address(0), "Bad fxManager address");
		fxManager = newFxManager;
	}

	function setConnectedToken(address newConnectedToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(connectedToken == address(0), "Connected token already set");
		connectedToken = newConnectedToken;
	}
}
