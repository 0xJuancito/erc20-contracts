pragma solidity ^0.6.2;


/**
ERC20 Token
 
Symbol          : IOI
Name            : IOI Token
Total supply    : 100000000
Decimals        : 6
 
*/
 
abstract contract ERC20Interface {
  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;
  function balanceOf(address _owner) public view virtual returns (uint256 balance);
  function transfer(address _to, uint256 _value) public virtual returns (bool success);
  function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool success);
  function approve(address _spender, uint256 _value) public virtual returns (bool success);
  function allowance(address _owner, address _spender) public view virtual returns (uint256 remaining);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

abstract contract TokenRecipient {
 function receiveApproval(address _from, uint256 _value, address _token, bytes memory _extraData) public virtual;
}

contract IOIToken is ERC20Interface {
 mapping (address => uint256) _balances;
 mapping (address => mapping (address => uint256)) _allowed;
 address public childChainManagerProxy;
 address deployer;
 using SafeMath for uint256;
  
 constructor(address _childChainManagerProxy) public {
   name = "IOI Token";
   symbol = "IOI";
   decimals = 6;
   totalSupply = 100000000 * 10 ** uint256(decimals);
   _balances[msg.sender] = totalSupply;
   childChainManagerProxy = _childChainManagerProxy;
   deployer = msg.sender;
 }
 
 event Burn(address indexed from, uint256 value);
 
 function balanceOf(address _owner) public view override returns (uint256 balance) {
   return _balances[_owner];
 }
 
 function transfer(address _to, uint256 _value) public override returns (bool success) {
   _transfer(msg.sender, _to, _value);
   return true;
 }
 
 function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
   require(_value <= _allowed[_from][msg.sender]);
   _allowed[_from][msg.sender] -= _value;
   _transfer(_from, _to, _value);
   return true;
 }
 
 function approve(address _spender, uint256 _value) public override returns (bool success) {
   _allowed[msg.sender][_spender] = _value;
   emit Approval(msg.sender, _spender, _value);
   return true;
 }
 
 function allowance(address _owner, address _spender) public view override returns (uint256 remaining) {
   return _allowed[_owner][_spender];
 }
 
 function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
   TokenRecipient spender = TokenRecipient(_spender);
   approve(_spender, _value);
   spender.receiveApproval(msg.sender, _value, address(this), _extraData);
   return true;
 }
 
 function burn(uint256 _value) public returns (bool success) {
   require(_balances[msg.sender] >= _value);
   _balances[msg.sender] -= _value;
   totalSupply -= _value;
   emit Burn(msg.sender, _value);
   return true;
 }
 
 function burnFrom(address _from, uint256 _value) public returns (bool success) {
   require(_balances[_from] >= _value);
   require(_value <= _allowed[_from][msg.sender]);
   _balances[_from] -= _value;
   _allowed[_from][msg.sender] -= _value;
   totalSupply -= _value;
   emit Burn(_from, _value);
   return true;
 }
 
 function _transfer(address _from, address _to, uint _value) internal {
   require(_to != address(0x0));
   require(_balances[_from] >= _value);
   require(_balances[_to] + _value > _balances[_to]);
  
   uint previousBalances = _balances[_from] + _balances[_to];
   _balances[_from] -= _value;
   _balances[_to] += _value;
   emit Transfer(_from, _to, _value);
   assert(_balances[_from] + _balances[_to] == previousBalances);
 }

 function updateChildChainManager(address newChildChainManagerProxy) external {
   require(newChildChainManagerProxy != address(0), "Bad ChildChainManagerProxy address");
   require(msg.sender == deployer, "You're not allowed");

   childChainManagerProxy = newChildChainManagerProxy;
 }

 function deposit(address user, bytes calldata depositData) external {
    require(msg.sender == childChainManagerProxy, "You're not allowed to deposit");

    uint256 amount = abi.decode(depositData, (uint256));

    totalSupply = totalSupply.add(amount);
    _balances[user] = _balances[user].add(amount);
        
    emit Transfer(address(0), user, amount);
 }

 function withdraw(uint256 amount) external {
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    totalSupply = totalSupply.sub(amount);
        
    emit Transfer(msg.sender, address(0), amount);
 }
  
 fallback() external payable {
   revert();
 }
 
 receive() external payable{
   revert();
 }
 
}