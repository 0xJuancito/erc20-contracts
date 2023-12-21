// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import { ILidoStaking } from "./interfaces/ILidoStaking.sol";

abstract contract StakingHook is ERC20Upgradeable, OwnableUpgradeable {

  /**********
   * Events *
   **********/

  /// @notice Emitted when the staking contract is updated.
  /// @param staking The address of new staking.
  event UpdateStaking(address staking);

  /*************
   * Variables *
   *************/
  
  /// @notice The address of Staking contract.
  address public staking;

  /****************************
   * Public Mutated Functions *
   ****************************/

  /// @notice Change address of staking contract.
  /// @param _staking The new address of staking contract.
  function updateStaking(address _staking) public onlyOwner {
    staking = _staking;

    emit UpdateStaking(_staking);
  }
  
  /**********************
   * Internal Functions *
   **********************/

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20Upgradeable) {
    super._transfer(from, to, amount);
    _afterTokenTransfer(from, to, amount);
  }

  function _mint(address account, uint256 amount) internal virtual override(ERC20Upgradeable) {
    super._mint(account, amount);
    _afterTokenTransfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual override(ERC20Upgradeable) {
    super._burn(account, amount);
    _afterTokenTransfer(account, address(0), amount);
  }

  function _afterTokenTransfer(address from, address to, uint256) internal {
    if (staking != address(0)) {
      ILidoStaking _staking = ILidoStaking(staking);
    
      if (!_staking.blackListAccounts(from) && from != address(0)) {
        _staking.stake(from, balanceOf(from));
      }
      if (!_staking.blackListAccounts(to) && to != address(0) && from != to) {
        _staking.stake(to, balanceOf(to));
      }
    }
  }
  uint256[49] private __gap;
}