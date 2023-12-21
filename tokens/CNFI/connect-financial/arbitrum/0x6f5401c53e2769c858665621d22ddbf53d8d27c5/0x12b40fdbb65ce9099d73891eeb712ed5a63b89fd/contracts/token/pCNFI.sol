// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {
  ERC20Upgradeable
} from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import { StringUtils } from '../util/Strings.sol';
import {
  OwnableUpgradeable
} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { pCNFILib } from './lib/pCNFILib.sol';

contract pCNFI is ERC20Upgradeable, OwnableUpgradeable {
  using StringUtils for *;

  function initialize(uint256 cycle) public initializer {
    __ERC20_init_unchained(pCNFILib.toName(cycle), pCNFILib.toSymbol(cycle));
    __Ownable_init_unchained();
  }

  function mint(address target, uint256 amount) public onlyOwner {
    _mint(target, amount);
  }

  function burn(address target, uint256 amount) public onlyOwner {
    _burn(target, amount);
  }
}
