// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/ERC20Burnable.sol";
import "./interfaces/ERC20Mintable.sol";

contract TangibleERC20 is ERC20, AccessControl, ERC20Burnable, ERC20Mintable {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    uint256 public constant MAX_SUPPLY = 33333333e18;

    constructor() ERC20("Tangible", "TNGBL") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function burnFrom(address who, uint256 amount)
        public
        override
        onlyRole(BURNER_ROLE)
    {
        uint256 currentAllowance = allowance(who, msg.sender);
        require(currentAllowance >= amount, "burn amount exceeds allowance");
        unchecked {
            _approve(who, msg.sender, currentAllowance - amount);
        }
        _burn(who, amount);
    }

    function mintFor(address who, uint256 amount)
        public
        override
        onlyRole(MINTER_ROLE)
    {
        _mint(who, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
        require(totalSupply() <= MAX_SUPPLY, "max. supply exceeded");
    }
}
