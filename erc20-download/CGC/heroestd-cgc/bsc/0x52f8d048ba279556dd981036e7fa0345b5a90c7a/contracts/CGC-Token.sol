// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract BPContract {
  function protect(
    address sender,
    address receiver,
    uint256 amount
  ) external virtual;
}

contract CGC is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable {
  BPContract public BP;
  bool public bpEnabled;
  bool public BPDisabledForever = false;

  constructor() ERC20("HeroesTD CGC", "CGC") {
  }

  function snapshot() public onlyOwner {
    _snapshot();
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  function setBPAddrss(address _bp) external onlyOwner {
    // require(address(BP) == address(0), "Can only be initialized once");
    BP = BPContract(_bp);
  }

  function setBpEnabled(bool _enabled) external onlyOwner {
    bpEnabled = _enabled;
  }

  function setBotProtectionDisableForever() external onlyOwner {
    require(BPDisabledForever == false);
    BPDisabledForever = true;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
    if (bpEnabled && !BPDisabledForever) {
      BP.protect(from, to, amount);
    }
    super._beforeTokenTransfer(from, to, amount);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20) {
    super._afterTokenTransfer(from, to, amount);
  }
}
