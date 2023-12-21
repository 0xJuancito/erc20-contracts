// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

import "./preset/ERC20ABCS.sol";

/**
 * @dev Basic preset of ERC20 token contract that includes the following extensions:
 *      - ERC20Snapshot (OpenZeppelin)
 *      - ERC20Capped (OpenZeppelin)
 *      - ERC20Burnable (OpenZeppelin)
 *      - AccessControl (OpenZeppelin)
 *      - ERC1363 (OpenZeppelin)
 */
contract ERC20Simple is ERC20ABCS {
  constructor(string memory name, string memory symbol, uint256 cap) ERC20ABCS(name, symbol, cap) {}

  /**
   * @notice No tipping!
   * @dev Reject all Ether from being sent here
   */
  receive() external payable {
    revert();
  }
}
