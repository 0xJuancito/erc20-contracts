// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ChappyzToken is
  ERC20,
  ERC20Burnable,
  ERC20Permit
{

  uint256 constant public TOTAL_SUPPLY = 10000000000 * (10 ** 10); // 10B + 10 decimals

  /**
  * Cap to 10B tokens on TGE.
  */
  constructor() ERC20("Chappyz", "CHAPZ") ERC20Permit("Chappyz") {
    _mint(0x7B32fadEd0C842B9ead0054d6688A7B92548B7A8, 750000000 * (10 ** 10));  // pre-seed
    _mint(0xbd83c509DF139cEb5944855C7f312986de1d2d75, 750000000 * (10 ** 10));  // seed
    _mint(0xA26C8Fd8DCAe2E7D23Ece6Ab357fbff40Ffccf52, 500000000 * (10 ** 10));  // strategic
    _mint(0x221dF6BeF35f84180fF7346f6DeC6e24fBA8854a, 1600000000 * (10 ** 10)); // public
    _mint(0xF3330De3B74424f91D39bA035C3c40A8ab25423A, 1400000000 * (10 ** 10)); // team
    _mint(0x7ED7907ED3BD217Ecc745CAAFd47FeAAD1dB80e4, 700000000 * (10 ** 10));  // advisors
    _mint(0x0892f7bA2677b324180500AbE26485152091aEa2, 2500000000 * (10 ** 10)); // rewards
    _mint(0x51Ea9D6d01168c96E5273d492002be5663329142, 750000000 * (10 ** 10));  // treasury
    _mint(0x14b28a834e4cC56202490787EEe9965D8f5c01AB, 1050000000 * (10 ** 10)); // liquidity
  }

  /**
  * @dev See {ERC20-decimals}.
  */
  function decimals() public pure override returns (uint8) {
    return 10;
  }

}