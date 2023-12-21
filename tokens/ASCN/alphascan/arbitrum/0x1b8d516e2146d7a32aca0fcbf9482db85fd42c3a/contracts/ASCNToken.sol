// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./openzeppelin/contracts/access/Ownable.sol";

contract ASCNToken is ERC20("AlphaScan", "ASCN"), ERC20Burnable, Ownable {
  uint256 immutable public maxSupply;

  struct Minter {
    address minter;
    uint256 allocation;
    uint256 minted;
    bool revoked;
  }

  mapping(address => Minter) public minters;
  uint256 public totalAllocation;

  constructor(uint256 _maxSupply) {
    maxSupply = _maxSupply;
  }

  function addMinter(address _minter, uint256 _allocation) external onlyOwner {
    require(_minter!=address(0), "addMinter: invalid minter");
    require(_allocation>0 && (totalAllocation+_allocation <= maxSupply), "addMinter: invalid allocation");
    require(minters[_minter].minter==address(0), "addMinter: duplicate minter");

    totalAllocation += _allocation;
    minters[_minter] = Minter(_minter, _allocation, 0, false);
  }

  function revokeMinter(address _minter) external onlyOwner {
    Minter storage minter = minters[_minter];
    require(minter.minter!=address(0), "mint: invalid minter");
    require(!minter.revoked, "revokeMinter: minter already revoked");

    minter.revoked = true;
    totalAllocation -= (minter.allocation - minter.minted);
  }

  function addAllocation(address _minter, uint256 _allocation) external onlyOwner {
    Minter storage minter = minters[_minter];
    require(minter.minter!=address(0), "addAllocation: invalid minter");
    require(!minter.revoked, "addAllocation: minter revoked");
    require(_allocation>0 && (totalAllocation+_allocation <= maxSupply), "addAllocation: invalid allocation");

    totalAllocation += _allocation;
    minter.allocation += _allocation;
  }

  function reduceAllocation(address _minter, uint256 _allocation) external onlyOwner {
    Minter storage minter = minters[_minter];
    require(minter.minter!=address(0), "reduceAllocation: invalid minter");
    require(!minter.revoked, "reduceAllocation: minter revoked");
    require(_allocation>0 && (minter.allocation-minter.minted >= _allocation), "reduceAllocation: invalid allocation");

    minter.allocation -= _allocation;
    totalAllocation -= _allocation;
  }

  // Only designated minters can mint (up to their respective allocations)
  function mint(address account, uint256 amount) external {
    require(ERC20.totalSupply() + amount <= maxSupply, "mint: max supply exceeded");
    Minter storage minter = minters[msg.sender];
    require(minter.minter!=address(0), "mint: invalid minter");
    require(!minter.revoked, "mint: minter revoked");
    require(minter.allocation - minter.minted >= amount, "mint: minter allocation exceeded");
    minter.minted += amount;

    super._mint(account, amount);
  }
}
