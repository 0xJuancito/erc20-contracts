//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./BEP20.sol";

contract ZmineToken is BEP20('ZMINE Token', 'ZMN') {
  
  /**
    * @dev Destroys `amount` tokens from the caller.
    *
    * See {ERC20-_burn}.
    */
  function burn(uint256 amount) public onlyOwner {
      _burn(_msgSender(), amount);
  }

  /**
    * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
    * the total supply.
    *
    * Requirements
    *
    * - `msg.sender` must be the token owner
    */
  function mint(uint256 amount) public onlyOwner returns (bool) {
      _mint(_msgSender(), amount);
      return true;
  }
  
}
