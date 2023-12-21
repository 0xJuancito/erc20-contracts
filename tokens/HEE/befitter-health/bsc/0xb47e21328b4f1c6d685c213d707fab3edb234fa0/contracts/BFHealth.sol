// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BFOperator.sol";

contract BFHealthToken is ERC20, BeFitterOperator {

    event MintHealthToken(address indexed to, uint256 amount, string message);

    constructor() ERC20("BFHealthToken", "HEE") {
        _operators[msg.sender] = true;
        _mint(msg.sender, 10000000 * 10**18);
    }

    function mint(address to, uint256 amount, string memory message)
        external
        onlyOperators
    {
        _mint(to, amount);
        emit MintHealthToken(to, amount, message);
    }
}