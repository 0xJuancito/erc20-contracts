// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "../../interfaces/IVault.sol";

contract TokenAuth is Context {
  address internal bk;
  address internal mn;
  address internal developmentAddress;
  address internal clsAddress;
  IVault public vault;

  constructor() {
    mn = msg.sender;
    bk = msg.sender;
  }

  modifier onlyMn() {
    require(isOwner(), "onlyMn");
    _;
  }

  modifier onlyBk() {
    require(isBk(), "onlyBk");
    _;
  }

  modifier onlyDevelopment() {
    require(_msgSender() == developmentAddress || isOwner(), "TokenAuth: invalid caller");
    _;
  }

  modifier onlyCLS() {
    require(msg.sender == clsAddress, "TokenAuth: invalid caller");
    _;
  }

  modifier onlyVault() {
    require(msg.sender == address(vault), "TokenAuth: invalid caller");
    _;
  }

  function updateBk(address _newBk) external onlyBk {
    require(_newBk != address(0), "TokenAuth: invalid new bk");
    bk = _newBk;
  }

  function updateMn(address _newMn) external onlyBk {
    require(_newMn != address(0), "TokenAuth: invalid new mn");
    mn = _newMn;
  }

  function isOwner() public view returns (bool) {
    return _msgSender() == mn;
  }

  function isBk() public view returns (bool) {
    return _msgSender() == bk;
  }
}
