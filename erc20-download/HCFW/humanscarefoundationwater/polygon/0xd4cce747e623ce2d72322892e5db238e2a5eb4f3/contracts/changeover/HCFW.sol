// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IBlacklist} from "../interfaces/IBlacklist.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract HCFW is ERC20, ERC20Permit, ERC20Burnable, AccessControl {

    string public hcfw = "Humans Care Foundation: Water";

    IBlacklist public blacklist;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(
        address blacklist_,
        address owner
    ) 
        ERC20(hcfw, "HCFW") 
        ERC20Permit("HCFW")
    {
        blacklist = IBlacklist(blacklist_);
        _mint(msg.sender, 21_000_000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    function _transfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20)
    {
        require(!blacklist.checkBlacklist(from), "This address is blacklisted");
        super._transfer(from, to, amount);
    }

    function penaltyTransfer(address from, address to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(blacklist.checkBlacklist(from), "This address is not blacklisted");
        _burn(from, amount);
        _mint(to, amount);
    }
}