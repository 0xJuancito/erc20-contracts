pragma solidity ^0.8.0;

contract Operator {
    mapping(address => bool) internal _operators;

    constructor() {
        _operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        require(_operators[msg.sender] == true, "Not operator");
        _;
    }

    function setOperator(address _user, bool _value) external onlyOperator {
        _operators[_user] = _value;
    }
}
