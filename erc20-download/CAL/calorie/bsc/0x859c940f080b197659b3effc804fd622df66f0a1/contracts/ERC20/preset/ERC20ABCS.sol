// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import "./ERC20ABC.sol";

contract ERC20ABCS is ERC20ABC, ERC20Snapshot {
  constructor(string memory name, string memory symbol, uint256 cap) ERC20ABC(name, symbol, cap) {
    _setupRole(SNAPSHOT_ROLE, _msgSender());
  }

  function snapshot() public onlyRole(SNAPSHOT_ROLE) {
    _snapshot();
  }

  function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20ABC) {
    super._mint(account, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Snapshot) {
    super._beforeTokenTransfer(from, to, amount);
  }
}
