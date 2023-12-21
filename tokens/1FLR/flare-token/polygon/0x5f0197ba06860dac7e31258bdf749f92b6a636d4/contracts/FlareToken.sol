// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FlareToken is ERC20 {

  constructor() ERC20("Flare Token", "1FLR") {
    _mint(msg.sender, 4 * 1000 * 1000 * 1000 * 10 ** decimals()); // 4B token
  }

  /**
   * Send to many
   */
  function sendToMany(address[] calldata recipients, uint256[] calldata amounts) external returns (bool) {

    require(recipients.length <= 1000, "ERC20: total of recipients should not greater than 1000");
	require(recipients.length == amounts.length, "ERC20: total of recipients should should be equal to total of amounts");

    uint16 i = 0;
    for (i; i < recipients.length; i++) {
      _transfer(_msgSender(), recipients[i], amounts[i]);
    }

    return true;
  }

}
