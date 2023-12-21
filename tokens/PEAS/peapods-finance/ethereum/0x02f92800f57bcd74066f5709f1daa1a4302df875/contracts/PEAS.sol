// https://peapods.finance

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/IPEAS.sol';

contract PEAS is IPEAS, ERC20 {
  constructor() ERC20('Peapods', 'PEAS') {
    _mint(_msgSender(), 10_000_000 * 10 ** 18);
  }

  function burn(uint256 _amount) external override {
    _burn(_msgSender(), _amount);
    emit Burn(_msgSender(), _amount);
  }
}
