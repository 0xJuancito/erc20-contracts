//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SLGERC20 is ERC20 {
    address public owner;
    uint256 public cap;

    mapping(address => bool) public blackList;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        address owner_
    ) ERC20(name_, symbol_){
        owner = owner_;
        cap = cap_;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        if (totalSupply() + amount > cap) amount = cap - totalSupply();
        _mint(account, amount);
    }

    function lockAddress(address haker) public onlyOwner {
        blackList[haker] = true;
    }

    function unLockAddress(address haker) public onlyOwner {
        blackList[haker] = false;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {
        require(!blackList[from], "black list error");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }
}
