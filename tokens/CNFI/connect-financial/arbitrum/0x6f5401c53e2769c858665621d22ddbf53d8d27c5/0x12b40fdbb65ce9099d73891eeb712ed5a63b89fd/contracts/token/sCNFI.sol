// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract sCNFI is ERC20Upgradeable, OwnableUpgradeable {
  function initialize() public initializer {
    __ERC20_init_unchained("Connect Financial Staking", "sCNFI");
    __Ownable_init_unchained();
  }

  function mint(address target, uint256 amount) public onlyOwner {
    _mint(target, amount);
  }

  function burn(address target, uint256 amount) public onlyOwner {
    _burn(target, amount);
  }

  function transfer(address target, uint256 amount)
    public
    override
    onlyOwner
    returns (bool)
  {
    return super.transfer(target, amount);
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override onlyOwner returns (bool) {
    return super.transferFrom(from, to, amount);
  }
}
