// SPDX-License-Identifier: GPL-2.0-only

/**
 * @title DYMMAX token
 * @author Fima
 */

pragma solidity >=0.6.0 <0.8.0;

import "./ERC20.sol";
import "./ERC20Burnable.sol";

contract DMX is ERC20, ERC20Burnable {

  constructor() ERC20("DYMMAX Governance Token", "DMX") public {
    _mint(msg.sender, 10**7 * 10**18);
  }
}