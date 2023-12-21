// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IFee } from "./Fee.sol";

// Carbon & LightLink 2023

contract CarbonToken is Ownable2Step, ERC20 {
  address public feeContract = 0x111541df26BeD3BcBEa90463bBB46F89fd95Ec1E;

  constructor() ERC20("Carbon", "CSIX") {
    _mint(0x43E4738Ac9309D2835F52918908B065FB8d1Fea0, 1_000_000_000 * (10**decimals()));
  }

  function transfer(address to, uint256 amount) public virtual override returns (bool) {
    if (feeContract == address(0) || IFee(feeContract).masterAccount() == address(0)) {
      return super.transfer(to, amount);
    }

    address owner = _msgSender();
    address master = IFee(feeContract).masterAccount();
    (uint256 fee, uint256 receipts) = IFee(feeContract).extractFee(owner, amount);
    _transfer(owner, master, fee);
    _transfer(owner, to, receipts);
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    if (feeContract == address(0) || IFee(feeContract).masterAccount() == address(0)) {
      return super.transfer(to, amount);
    }

    address spender = _msgSender();
    _spendAllowance(from, spender, amount);
    address master = IFee(feeContract).masterAccount();
    (uint256 fee, uint256 receipts) = IFee(feeContract).extractFee(spender, amount);
    _transfer(from, master, fee);
    _transfer(from, to, receipts);
    return true;
  }

  /* Admin */
  function setFeeContract(address _contract) public onlyOwner {
    feeContract = _contract;
  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }
}
