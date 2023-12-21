// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./BasicToken.sol";


abstract contract IBEP20 is BEP20Basic {
    function allowance(address owner, address spender) public virtual view returns (uint256);
    function approve(address spender, uint256 value) public virtual returns (bool);
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract StandardToken is IBEP20, BasicToken {
    using SafeMath for uint256;
    mapping(address => mapping(address => uint256)) private _allowed;

    function approve(address spender, uint256 value) public override stoppable validRecipient(spender) returns(bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    
    function _approve(address _owner, address spender, uint256 value) private {
        _allowed[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    function transferFrom(address from, address to, uint256 value) public override stoppable validRecipient(to) returns(bool) {
        require(_allowed[from][msg.sender] >= value);
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    function allowance(address _owner, address _spender) public override view returns (uint256) {
        return _allowed[_owner][_spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) public stoppable validRecipient(spender) returns(bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractValue) public stoppable validRecipient(spender) returns(bool) {
        uint256 oldValue = _allowed[msg.sender][spender];
        if(subtractValue > oldValue) {
            _approve(msg.sender, spender, 0);
        }
        else {
            _approve(msg.sender, spender, oldValue.sub(subtractValue));
        }
        return true;
    }

    function mint(address account, uint256 amount) public onlyOwner stoppable validRecipient(account) returns(bool) {
        totalSupply = totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
        return true;
    }

    function burn(uint256 amount) public stoppable onlyOwner returns(bool) {
        require(amount > 0 && _balances[msg.sender] >= amount);
        totalSupply = totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }
}