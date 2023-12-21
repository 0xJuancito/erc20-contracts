pragma solidity 0.8.9;
import "./basictoken.sol";
import "./erc20.sol";

contract StandardToken is ERC20, BasicToken {
  mapping(address => mapping(address => uint256)) internal allowed;

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public returns (bool) {
    require(_to != address(0), "To cannot be ZERO ADDRESS");
    require(_from != address(0), "From cannot be Address 0");
    require(_value <= balances[_from], "Insufficient Balance");
    require(
      _value <= allowed[_from][msg.sender],
      "msg sender not approved of this amount"
    );
    unchecked {
      balances[_from] = balances[_from] - _value;
      allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value;
    }

    balances[_to] = balances[_to] + _value;

    emit Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint256 _value)
    public
    override
    returns (bool)
  {
    require(_spender != address(0), "Spender cannot be ZERO ADDRESS");
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender)
    public
    view
    override
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }

  function increaseApproval(address _spender, uint256 _addedValue)
    public
    returns (bool)
  {
    require(_spender != address(0), "Spender cannot be ZERO ADDRESS");
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender] + _addedValue;
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval(address _spender, uint256 _subtractedValue)
    public
    returns (bool)
  {
    require(_spender != address(0), "Spender cannot be ZERO ADDRESS");
    uint256 oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      unchecked { allowed[msg.sender][_spender] = oldValue - _subtractedValue; }
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
}
