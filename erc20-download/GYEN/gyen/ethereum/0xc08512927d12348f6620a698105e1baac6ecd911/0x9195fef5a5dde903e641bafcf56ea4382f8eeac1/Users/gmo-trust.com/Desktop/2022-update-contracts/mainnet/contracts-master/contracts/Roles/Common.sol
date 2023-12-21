pragma solidity 0.5.8;

contract Common {
    modifier isNotZeroAddress(address _account) {
        require(_account != address(0), "this account is the zero address");
        _;
    }

    modifier isNaturalNumber(uint256 _amount) {
        require(0 < _amount, "this amount is not a natural number");
        _;
    }
}