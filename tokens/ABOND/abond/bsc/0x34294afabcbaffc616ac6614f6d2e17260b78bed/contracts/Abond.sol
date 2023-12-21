// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Abond is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint _initialSupply
    ) ERC20(_name, _symbol) ERC20Permit(_name) Ownable() {
        _mint(_msgSender(), _initialSupply);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._burn(account, amount);
    }
}
