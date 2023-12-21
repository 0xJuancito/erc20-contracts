// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Helper.sol";

contract ERA7Token is ERC20,Helper {

  uint256 public maxMint;

  constructor() ERC20("Era Token", "ERA") {
    uint256 decimal = 10 ** uint256(decimals());
    maxMint = 1000000000 * decimal;
  }

  function mint(address to,uint256 amount) external onlyHelper {
    require(to != address(0), "ERA7Token:to address error");
    
    uint256 newVal = SafeMath.add(amount,totalSupply());
    require(newVal <= maxMint, "ERA7Token:mint value is max");
    _mint(to,amount);
  }


  function burn(uint256 amount) external {
      _burn(_msgSender(), amount);
  }

  function burnFrom(address account, uint256 amount) external {
      uint256 currentAllowance = allowance(account, _msgSender());
      require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
      unchecked {
          _approve(account, _msgSender(), currentAllowance - amount);
      }
      _burn(account, amount);
  }

}
