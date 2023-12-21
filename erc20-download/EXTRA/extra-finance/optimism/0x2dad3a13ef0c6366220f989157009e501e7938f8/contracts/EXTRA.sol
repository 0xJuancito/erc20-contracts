// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./external/openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./external/openzeppelin/contracts/access/Ownable.sol";

contract EXTRA is ERC20, Ownable {
    uint256 internal immutable supplyCap;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _supplyCap
    ) ERC20(name, symbol) {
        supplyCap = _supplyCap;
    }

    function cap() public view returns (uint256) {
        return supplyCap;
    }

    function mint(uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= cap(), "suplly cap exceeded");

        _mint(msg.sender, amount);
    }
}
