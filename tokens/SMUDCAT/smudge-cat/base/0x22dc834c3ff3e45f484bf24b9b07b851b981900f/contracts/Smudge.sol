// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./Governable.sol";

contract Smudge is ERC20Votes, Governable {
    uint256 MAX_MINTABLE = 500_000_000_000 * 10**18;
    mapping(address => bool) public permittedMinter;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_symbol) {
        gov = msg.sender;
    }

    function setMinter(address _contractAddress, bool _bool) external onlyGov {
        permittedMinter[_contractAddress] = _bool;
    }

    function mint(address _to, uint256 _amount) external returns (bool) {
        require(permittedMinter[msg.sender], "Not permitted minter");
        require(totalSupply() + _amount <= MAX_MINTABLE, "Max mintable exceeded");
        _mint(_to, _amount);
        return true;
    }
}