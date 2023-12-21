// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../../interface/IERC20.sol";

contract LizardUsdcStg is IERC20 {

  string public constant symbol = "slzUSDC";
  string public constant name = "SolidLizard synthetic USDC";
  uint8 public constant decimals = 6;
  uint public override totalSupply = 0;

  mapping(address => uint) public override balanceOf;
  mapping(address => mapping(address => uint)) public override allowance;

  address public minter;

  constructor() {
    minter = msg.sender;
  }

  // No checks as its meant to be once off to set minting rights to Minter
  function setMinter(address _minter) external {
    require(msg.sender == minter, "LIZARD: Not minter");
    minter = _minter;
  }

  function approve(address _spender, uint _value) external override returns (bool) {
    require(_spender != address(0), "LIZARD: Approve to the zero address");
    allowance[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function _mint(address _to, uint _amount) internal returns (bool) {
    require(_to != address(0), "LIZARD: Mint to the zero address");
    balanceOf[_to] += _amount;
    totalSupply += _amount;
    emit Transfer(address(0x0), _to, _amount);
    return true;
  }

  function _burn(address _from, uint256 _amount) internal returns (bool) {
    require(_from != address(0), "LIZARD: burn from the zero address");
    uint fromBalance = balanceOf[_from];
    require(_amount <= fromBalance, "LIZARD: burn amount exceeds balance");
    unchecked {
        balanceOf[_from] = fromBalance - _amount;
        totalSupply = totalSupply - _amount;
    }
        
    emit Transfer(_from, address(0x0), _amount);
    return true;
  }

  function _transfer(address _from, address _to, uint _value) internal returns (bool) {
    require(_to != address(0), "LIZARD: Transfer to the zero address");

    uint fromBalance = balanceOf[_from];
    require(fromBalance >= _value, "LIZARD: Transfer amount exceeds balance");
  unchecked {
    balanceOf[_from] = fromBalance - _value;
  }

    balanceOf[_to] += _value;
    emit Transfer(_from, _to, _value);
    return true;
  }

  function transfer(address _to, uint _value) external override returns (bool) {
    return _transfer(msg.sender, _to, _value);
  }

  function transferFrom(address _from, address _to, uint _value) external override returns (bool) {
    address spender = msg.sender;
    uint spenderAllowance = allowance[_from][spender];
    if (spenderAllowance != type(uint).max) {
      require(spenderAllowance >= _value, "LIZARD: Insufficient allowance");
    unchecked {
      uint newAllowance = spenderAllowance - _value;
      allowance[_from][spender] = newAllowance;
      emit Approval(_from, spender, newAllowance);
    }
    }
    return _transfer(_from, _to, _value);
  }

  function mint(address account, uint amount) external returns (bool) {
    require(msg.sender == minter, "LIZARD: Not minter");
    return _mint(account, amount);
  }

  function burn(address account, uint amount) external returns (bool) {
    require(msg.sender == minter, "LIZARD: Not minter");
    return _burn(account, amount);
  }
}
