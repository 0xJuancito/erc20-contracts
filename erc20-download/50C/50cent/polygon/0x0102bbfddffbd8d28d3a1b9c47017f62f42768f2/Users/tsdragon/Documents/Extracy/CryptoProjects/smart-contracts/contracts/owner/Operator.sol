// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Operator is Context, Ownable {
    address private _operator;
    address private _secondOperator;

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event SecondOperatorTransferred(address indexed previousSecondOperator, address indexed newSecondOperator);

    constructor() internal {
        _operator = _msgSender();
        _secondOperator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
        emit SecondOperatorTransferred(address(0), _secondOperator);
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function secondOperator() public view returns (address) {
        return _secondOperator;
    }

    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    modifier onlySecondOperator() {
        require(_secondOperator == msg.sender || _operator == msg.sender, "operator: caller is not the operator nor the second operator");
        _;
    }

    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    function isSecondOperator() public view returns (bool) {
        return _msgSender() == _secondOperator || _msgSender() == _operator;
    }

    function transferOperator(address newOperator_) public onlyOwner {
        _transferOperator(newOperator_);
    }

    function _transferOperator(address newOperator_) internal {
        require(newOperator_ != address(0), "operator: zero address given for new operator");
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }

    function transferSecondOperator(address newSecondOperator_) public onlySecondOperator {
        _transferSecondOperator(newSecondOperator_);
    }

    function _transferSecondOperator(address newSecondOperator_) internal {
        require(newSecondOperator_ != address(0), "operator: zero address given for new second operator");
        emit SecondOperatorTransferred(address(0), newSecondOperator_);
        _operator = newSecondOperator_;
    }
}
