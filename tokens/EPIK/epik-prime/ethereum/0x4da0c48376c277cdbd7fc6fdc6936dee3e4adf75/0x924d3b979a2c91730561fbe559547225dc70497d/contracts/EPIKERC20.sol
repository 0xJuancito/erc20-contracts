// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "./Initializable.sol";

import "./v2/CappedEPIK.sol";
import "./v2/MintableEPIK.sol";
import "./v2/Ownable.sol";

/**
 * @title EPIK LOGIC TOKEN
 * @dev This contract is a mock to test initializable functionality
 */
contract EPIKERC20 is Initializable, ERC20Capped, ERC20Mintable, Ownable {

  function initialize(string memory name_, string memory symbol_, uint8 decimals_, uint256 cap_, address owner_) public initializer {
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
    _cap = cap_;
    _owner = owner_;
  }

  /**
    * @dev Function to mint tokens.
    *
    * NOTE: restricting access to owner only. See {ERC20Mintable-mint}.
    *
    * @param account The address that will receive the minted tokens
    * @param amount The amount of tokens to mint
    */
  function _mint(address account, uint256 amount) internal override onlyOwner {
      super._mint(account, amount);
  }

  /**
    * @dev Function to stop minting new tokens.
    *
    * NOTE: restricting access to owner only. See {ERC20Mintable-finishMinting}.
    */
  function _finishMinting() internal override onlyOwner {
      super._finishMinting();
  }

  /**
    * @dev See {ERC20-_beforeTokenTransfer}. See {ERC20Capped-_beforeTokenTransfer}.
    */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Capped) {
      super._beforeTokenTransfer(from, to, amount);
  }
}
