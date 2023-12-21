// SPDX-License-Identifier: none
pragma solidity 0.8.19;

import "ERC20.sol";
import "ERC20Capped.sol";
import "ERC20PresetMinterPauser.sol";


/*
  Minter/Burner is the esGOOD contract
  This is because rewards are distributed as esGOOD, later redeemed as GOOD after vesting
*/
contract GOOD is ERC20PresetMinterPauser, ERC20Capped {
  constructor() 
    ERC20PresetMinterPauser("Good Entry", "GOOD") 
    ERC20Capped(1e28)
  {}
  
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override (ERC20, ERC20PresetMinterPauser) {
    super._beforeTokenTransfer(from, to, amount);
  }

  
  function _mint(address account, uint256 amount) internal override (ERC20, ERC20Capped) {
    super._mint(account, amount);
  }
  
  function burn(address account, uint256 amount) onlyRole(MINTER_ROLE) public {
    _burn(account, amount);
  }
}