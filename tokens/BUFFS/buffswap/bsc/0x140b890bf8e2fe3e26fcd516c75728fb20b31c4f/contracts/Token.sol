// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol';

contract BuffSwap is ERC20PresetFixedSupply {
  uint8 internal constant _decimals = 4;

  constructor(
    string memory name,
    string memory symbol,
    uint256 totalSupply
  ) ERC20PresetFixedSupply(name, symbol, totalSupply, msg.sender) {}

  function decimals() public pure override returns (uint8) {
    return _decimals;
  }

  // Prevent token transfers to token address
  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    require(recipient != address(this), 'ERC20: transfer to token address');

    return super.transfer(recipient, amount);
  }

  // Prevent token transfers to token address
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    require(recipient != address(this), 'ERC20: transferFrom to token address');

    return super.transferFrom(sender, recipient, amount);
  }
}
