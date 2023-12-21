// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStakingController} from "../interfaces/IStakingController.sol";

contract ConnectToken is ERC20Upgradeable, OwnableUpgradeable {
  uint256 public unlockAt;
  mapping(address => bool) authorizedBeforeUnlock;
  bytes32 constant STAKING_CONTROLLER_SLOT = keccak256("staking-controller");

  function initialize() public initializer {
    __Ownable_init_unchained();
  }

  function getStakingController() public view returns (address returnValue) {
    bytes32 local = STAKING_CONTROLLER_SLOT;
    assembly {
      returnValue := and(
        0xffffffffffffffffffffffffffffffffffffffff,
        sload(local)
      )
    }
  }

  function setStakingController(address) public virtual {
    assembly {
      sstore(0x59195, 0x1)
    }
  } // stub

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    address own = getStakingController();
    if (own == msg.sender) _approve(from, own, amount);
    require(from != 0x2C6900b24221dE2B4A45c8c89482fFF96FFB7E55, "not allowed");
    return super.transferFrom(from, to, amount);
  }

  function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
  {
    require(
      msg.sender != 0x2C6900b24221dE2B4A45c8c89482fFF96FFB7E55,
      "not allowed"
    );
    return super.transfer(recipient, amount);
  }
}
