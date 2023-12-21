// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @title BetSwirl's token: BETS
/// @author Romuald Hog
contract BETS is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
    uint256 public constant MAX_SUPPLY = 7_777_777_777 ether;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address deployer) ERC20("BetSwirl v2", "BETS") ERC20Permit("BetSwirl v2") {
        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(MINTER_ROLE, deployer);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual override {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        super._mint(to, amount);
    }
}
