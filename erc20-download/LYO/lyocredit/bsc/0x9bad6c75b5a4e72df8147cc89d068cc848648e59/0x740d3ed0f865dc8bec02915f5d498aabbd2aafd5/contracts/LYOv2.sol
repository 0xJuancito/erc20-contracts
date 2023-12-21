// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
  __                   ______              ___ __
   / /   __  ______     / ____/_______  ____/ (_) /_
  / /   / / / / __ \   / /   / ___/ _ \/ __  / / __/
 / /___/ /_/ / /_/ /  / /___/ /  /  __/ /_/ / / /_
/_____/\__, /\____/   \____/_/   \___/\__,_/_/\__/
      /____/

*
* MIT License
* ===========
*
* Copyright (c) 2022 Lyo Credit (https://lyocredit.io)
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

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract LYO is Initializable, ContextUpgradeable, AccessControlUpgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable {

    bytes32 public constant FROZEN_ROLE = keccak256("FROZEN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) public virtual initializer {
        __LYO_init(name, symbol, initialSupply, owner);
    }

    function __LYO_init(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __LYO_init_unchained(name, symbol, initialSupply, owner);
    }

    function __LYO_init_unchained(
        string memory,
        string memory,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(PAUSER_ROLE, owner);
        _mint(owner, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
      return 8;
    }

    function pause() public {
      require(hasRole(PAUSER_ROLE, _msgSender()), "Must have pauser role to pause");
      _pause();
    }

    function unpause() public {
      require(hasRole(PAUSER_ROLE, _msgSender()), "Must have pauser role to unpause");
      _unpause();
    }

    function renounceRole(bytes32 role, address account) public override(AccessControlUpgradeable) {
      require(!hasRole(FROZEN_ROLE, _msgSender()), "Must not be frozen to invoke this method");
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");
        _revokeRole(role, account);
    }

    function recoverERC20(IERC20Upgradeable tokenAddress, address to, uint256 tokenAmount) public {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must be admin to invoke this method");
      SafeERC20Upgradeable.safeTransfer(tokenAddress, to, tokenAmount);
    }

    /**
    * @dev See {ERC20-_beforeTokenTransfer}.
    */

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
    require(!hasRole(FROZEN_ROLE, _msgSender()), "Must be not be frozen to send tokens");
    require(!hasRole(FROZEN_ROLE, from), "Must be not be frozen to send tokens");

    super._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
