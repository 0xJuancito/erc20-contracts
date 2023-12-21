// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @title XNET - ERC20 token
 * @author connexa@xnet.company
 *
 * @notice XNET is a conforming ERC20 token that provides the utility
 * foundation for the XNET ecosystem
 */

contract XNET is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
  constructor()
    ERC20("XNET Mobile", "XNET")
    ERC20Permit("XNET Mobile") {
    _mint(msg.sender, 24000000000 * 10 ** decimals());
  }
  // The functions below are overrides required by Solidity.

  function _afterTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
  {
    super._afterTokenTransfer(from, to, amount);
  }
  
  function _mint(address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
  {
    super._mint(to, amount);
  }
  
  function _burn(address account, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
  {
    super._burn(account, amount);
  }
}
