// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import  "./Pauseable.sol";

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
}

abstract contract BEP20Basic {
    uint public totalSupply;
     function balanceOf(address who) public virtual view returns (uint256);
     function transfer(address to, uint256 value) public virtual returns(bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

abstract contract BasicToken is BEP20Basic, Pauseable {
    
    using SafeMath for uint256;
    
    mapping(address => uint256) internal Frozen;
    
    mapping(address => uint256) internal _balances;
    
    function  transfer(address to, uint256 value) public override  stoppable validRecipient(to) returns(bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0));
        require(value > 0);
        require(_balances[from].sub(Frozen[from]) >= value);
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

   function balanceOf(address _owner)  public override view returns(uint256) {
      return _balances[_owner];
    }

    function availableBalance(address _owner) public view returns(uint256) {
        return _balances[_owner].sub(Frozen[_owner]);
    }

    function frozenOf(address _owner) public view returns(uint256) {
        return Frozen[_owner];
    }
 
    modifier validRecipient(address _recipient) {
        require(_recipient != address(0) && _recipient != address(this));
    _;
    }
}