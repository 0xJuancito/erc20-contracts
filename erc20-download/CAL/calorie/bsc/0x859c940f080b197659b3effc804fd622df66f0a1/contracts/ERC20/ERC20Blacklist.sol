// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

import "../extensions/BlackList.sol";

import "./ERC20Simple.sol";

/**
 * @dev Advanced preset of ERC20 token contract that includes the following extensions:
 *      - ERC20Simple (Gemunion)
 *      - BlackList (Gemunion)
 *        provides access list to restrict suspicious account from interaction with tokens
 */
contract ERC20Blacklist is ERC20Simple, BlackList {
  constructor(string memory name, string memory symbol, uint256 cap) ERC20Simple(name, symbol, cap) {}

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC20AB) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev Hook that is called before any transfer of tokens.
   *      Checks if the sender or receiver is blacklisted before the transfer is executed.
   *
   * @param from Sender address
   * @param to Receiver address
   * @param amount Amount of tokens to transfer
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    // Ensure the sender is not blacklisted
    require(from == address(0) || !_isBlacklisted(from), "Blacklist: sender is blacklisted");
    // Ensure the receiver is not blacklisted
    require(to == address(0) || !_isBlacklisted(to), "Blacklist: receiver is blacklisted");
    // Execute other hooks
    super._beforeTokenTransfer(from, to, amount);
  }
}
