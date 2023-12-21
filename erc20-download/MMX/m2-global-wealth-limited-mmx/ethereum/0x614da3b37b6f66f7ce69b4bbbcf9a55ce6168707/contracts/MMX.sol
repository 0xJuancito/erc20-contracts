// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MMX is ERC20 {
  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    address to
  ) ERC20(tokenName, tokenSymbol) {
    _mint(to, 500_000_000 ether);
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    require(sender != address(0), "ERC20: transfer from the zero address");

    if (recipient == address(0)) {
      _burn(sender, amount);
    } else {
      super._transfer(sender, recipient, amount);
    }
  }

  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }
}
