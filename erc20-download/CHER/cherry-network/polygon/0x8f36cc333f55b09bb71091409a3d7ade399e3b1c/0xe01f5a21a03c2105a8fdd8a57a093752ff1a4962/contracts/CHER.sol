// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*

_______   .---.  .---.     .-''-.  .-------.    .-------.       ____     __
/   __  \  |   |  |_ _|   .'_ _   \ |  _ _   \   |  _ _   \      \   \   /  /
| ,_/  \__) |   |  ( ' )  / ( ` )   '| ( ' )  |   | ( ' )  |       \  _. /  '
,-./  )       |   '-(_{;}_). (_ o _)  ||(_ o _) /   |(_ o _) /        _( )_ .'
\  '_ '`)     |      (_,_) |  (_,_)___|| (_,_).' __ | (_,_).' __  ___(_ o _)'
> (_)  )  __ | _ _--.   | '  \   .---.|  |\ \  |  ||  |\ \  |  ||   |(_,_)'
(  .  .-'_/  )|( ' ) |   |  \  `-'    /|  | \ `'   /|  | \ `'   /|   `-'  /
`-'`-'     / (_{;}_)|   |   \       / |  |  \    / |  |  \    /  \      /
`._____.'  '(_,_) '---'    `'-..-'  ''-'   `'-'  ''-'   `'-'    `-..-'


*
* MIT License
* ===========
*
* Copyright (c) 2022 Cherry Network (https://cherry.network)
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
* @title TokenRecover
* @dev Allow to recover any ERC20 sent into the contract for error
*/
contract TokenRecover is OwnableUpgradeable {

  /**
  * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
  * @param tokenAddress The token contract address
  * @param tokenAmount Number of tokens to be sent
  */
  function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
    IERC20Upgradeable(tokenAddress).transfer(owner(), tokenAmount);
  }
}


contract CHER  is Initializable, ContextUpgradeable, AccessControlEnumerableUpgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, TokenRecover {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // 0x4d494e5445525f524f4c45
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant SWAPPER_ROLE = keccak256("SWAPPER_ROLE");
  bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
  bytes32 public constant FROZEN_ROLE = keccak256("FROZEN_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  function initialize(string memory name, string memory symbol) public virtual initializer {
    __CHER_init(name, symbol);
  }
  function __CHER_init(string memory name, string memory symbol) internal initializer {
    __Context_init_unchained();
    __ERC165_init_unchained();
    __AccessControl_init_unchained();
    __AccessControlEnumerable_init_unchained();
    __ERC20_init_unchained(name, symbol);
    __ERC20Burnable_init_unchained();
    __Pausable_init_unchained();
    __ERC20Pausable_init_unchained();
    __CHER_init_unchained(name, symbol);
  }

  function __CHER_init_unchained(string memory name, string memory symbol) internal initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(BURNER_ROLE, _msgSender());
    _setupRole(FREEZER_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, _msgSender());
  }

  function mint(address to, uint256 amount) public virtual {
    require(hasRole(MINTER_ROLE, _msgSender()), "Must have minter role to mint");
    _mint(to, amount);
  }

  function batchMint(address[] memory to, uint256[] memory value) public {
    require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
    require(to.length == value.length, "Recipient and amount list sizes dont match.");
    for (uint i = 0; i < to.length; i++) {
      _mint(to[i], value[i]);
    }
  }

  event Swap(address indexed account, uint256 value, uint16 chainId);

  function swapBurn(uint256 amount, uint16 chainId) public virtual whenNotPaused {
    emit Swap(msg.sender, amount, chainId);
    _burn(_msgSender(), amount);
  }

  function swapMint(address[] memory to, uint256[] memory value) public {
    require(hasRole(SWAPPER_ROLE, _msgSender()), "Caller is not a minter");
    require(to.length == value.length, "Recipient and amount list sizes dont match.");
    for (uint i = 0; i < to.length; i++) {
      _mint(to[i], value[i]);
    }
  }

  function pause() public {
    require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
    _pause();
  }

  function unpause() public {
    require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
    _unpause();
  }

  function renounceRole(bytes32 role, address account) public virtual override {
    require(account == _msgSender(), "AccessControl: can only renounce roles for self");
    require(!hasRole(FROZEN_ROLE, _msgSender()), "Must be not be frozen to renounce role");
    require(!hasRole(FROZEN_ROLE, account), "Must be not be frozen to renounce role");

    _revokeRole(role, account);
}
  /**
  * @dev See {ERC20-_beforeTokenTransfer}.
  */

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
    require(!hasRole(FROZEN_ROLE, _msgSender()), "Must be not be frozen to send token");
    require(!hasRole(FROZEN_ROLE, from), "Must be not be frozen to send token");
    super._beforeTokenTransfer(from, to, amount);
  }
  uint256[50] private __gap;

}
