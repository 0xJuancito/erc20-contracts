// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

// Carbon & LightLink 2023

interface IFee {
  function masterAccount() external view returns (address);

  function extractFee(address _sender, uint256 _amount) external view returns (uint256 fee, uint256 sendAmount);
}

contract CarbonTokenFee is Ownable2Step, IFee {
  address public masterAccount = 0x43E4738Ac9309D2835F52918908B065FB8d1Fea0;
  uint256 public feeRate = 250;

  mapping(address => bool) public feeAddressList;

  constructor() {}

  function extractFee(address _sender, uint256 amount) public view returns (uint256, uint256) {
    if (!feeAddressList[_sender]) {
      return (0, amount);
    }
    uint256 fee = (amount * feeRate) / 10000;
    return (fee, amount - fee);
  }

  /* Admin */
  function setMasterAccount(address _account) public onlyOwner {
    masterAccount = _account;
  }

  function setFeeRate(uint256 _rate) public onlyOwner {
    require(_rate <= 10000, "Exceed max");
    feeRate = _rate;
  }

  function setFeeAddressList(address[] calldata _accounts, bool[] calldata _status) public onlyOwner {
    require(_accounts.length == _status.length, "Invalid input");
    for (uint256 i = 0; i < _accounts.length; i++) {
      feeAddressList[_accounts[i]] = _status[i];
    }
  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }
}
