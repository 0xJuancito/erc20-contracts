// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BeFitterOperator is Ownable {

    mapping(address => bool) _operators;

    constructor() {
        _operators[msg.sender] = true;
    }

    function setOperator(address operator) external onlyOwner {
        _operators[operator] = true;
    }

    function removeOperator(address operator) external onlyOwner {
        _operators[operator] = false;
    }

    function isOperator(address operator) external view returns (bool) {
        return _operators[operator];
    }

    modifier onlyOperators() {
        require(_operators[msg.sender], "caller is not the operators");
        _;
    }
}