// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/*

_____/\\\\\\\\\\\\____/\\\\\\\\\___________/\\\\\_______/\\\______________/\\\_
 ___/\\\//////////___/\\\///////\\\_______/\\\///\\\____\/\\\_____________\/\\\_
  __/\\\_____________\/\\\_____\/\\\_____/\\\/__\///\\\__\/\\\_____________\/\\\_
   _\/\\\____/\\\\\\\_\/\\\\\\\\\\\/_____/\\\______\//\\\_\//\\\____/\\\____/\\\__
    _\/\\\___\/////\\\_\/\\\//////\\\____\/\\\_______\/\\\__\//\\\__/\\\\\__/\\\___
     _\/\\\_______\/\\\_\/\\\____\//\\\___\//\\\______/\\\____\//\\\/\\\/\\\/\\\____
      _\/\\\_______\/\\\_\/\\\_____\//\\\___\///\\\__/\\\_______\//\\\\\\//\\\\\_____
       _\//\\\\\\\\\\\\/__\/\\\______\//\\\____\///\\\\\/_________\//\\\__\//\\\______
        __\////////////____\///________\///_______\/////____________\///____\///_______
         _______________________________________________________________________________*/

contract GrowToken is ERC20, ERC20Burnable, ERC20Capped, Ownable, AccessControlEnumerable {
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    bool public transfersEnabled = false;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Capped(100_000_000 ether) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Mint new tokens
    // (can only be called by contract owner, not by someone with the TRANSFER_ROLE or DEFAULT_ADMIN_ROLE role)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // In this implementation this is one-way: once transfers are enabled, they cannot be disabled again
    function enableTransfers() external onlyOwner {
        transfersEnabled = true;
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // Do the following check if transfers are not enabled yet
        if (!transfersEnabled) {
            // from address has to be either the zero address (mint event), the owner or someone with TRANSFER_ROLE
            require(from == address(0) || from == owner() || hasRole(TRANSFER_ROLE, from), "ERC20: transfers not enabled");
        }
    }
}
