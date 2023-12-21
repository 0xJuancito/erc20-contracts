// contracts/DaddyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SPENT is ERC20 {
  constructor(uint256 initialSupply, address to) ERC20("SPENT", "SPENT") {
    // 51 million , one time mint only
    _mint(to, initialSupply);
  }

  function burn(uint256 _amount) public {
    _burn(msg.sender, _amount);
  }
}
