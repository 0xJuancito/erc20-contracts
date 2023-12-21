// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LayerAIBridged is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    uint256 public constant MAX_TOTAL_SUPPLY = 3_000_000_000 ether;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("LayerAI Token", "LAI") ERC20Permit("LayerAI Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(
            totalSupply() + amount <= MAX_TOTAL_SUPPLY,
            "LayerAIBridged: MAX_TOTAL_SUPPLY exceeded"
        );
        _mint(to, amount);
    }
}
