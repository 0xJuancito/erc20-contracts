pragma solidity 0.5.8;

import "./Common.sol";

contract Operators is Common  {
    address public operator1 = address(0);
    address public operator2 = address(0);

    modifier onlyOperator() {
        require(msg.sender == operator1 || msg.sender == operator2, "the sender is not the operator");
        _;
    }

    function initializeOperators(address _account1, address _account2) internal {
        operator1 = _account1;
        operator2 = _account2;
    }
}