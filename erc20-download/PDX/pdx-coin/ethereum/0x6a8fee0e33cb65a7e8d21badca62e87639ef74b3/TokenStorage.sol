pragma solidity ^0.5.0;

contract TokenStorage {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    bool internal _tokensMinted = true;
}