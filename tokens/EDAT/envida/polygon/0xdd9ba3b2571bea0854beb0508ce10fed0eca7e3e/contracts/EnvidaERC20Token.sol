// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EnvidaERC20Token is ERC20Capped, Pausable, AccessControl {
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  constructor(
    string memory name,
    string memory symbol,
    uint256 initialSupply,
    uint256 cap
  ) ERC20(name, symbol) ERC20Capped(cap) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    ERC20._mint(msg.sender, initialSupply);
  }

  function burnFrom(address from, uint256 amount) public {
    require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
    _burn(from, amount);
  }

  function pause() public {
    require(
      hasRole(PAUSER_ROLE, _msgSender()),
      "Caller must have pauser role to pause"
    );
    _pause();
  }

  function unpause() public {
    require(
      hasRole(PAUSER_ROLE, _msgSender()),
      "Caller must have pauser role to unpause"
    );
    _unpause();
  }

  /**
   * @dev See {ERC20-_beforeTokenTransfer}.
   *
   * Requirements:
   *
   * - the contract must not be paused.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    require(!paused(), "ERC20Pausable: token transfer while paused");
  }
}
