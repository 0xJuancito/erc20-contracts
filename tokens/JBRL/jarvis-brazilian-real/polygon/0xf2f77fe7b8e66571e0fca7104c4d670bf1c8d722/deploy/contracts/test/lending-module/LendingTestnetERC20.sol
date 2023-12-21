// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import '../../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  SafeERC20
} from '../../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../../../@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../../../@openzeppelin/contracts/access/Ownable.sol';

contract LendingTestnetERC20 is Ownable, ERC20 {
  using SafeERC20 for IERC20;

  uint8 _decimals;
  IERC20 collateral;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _tokenDecimals,
    address _collateral,
    address _owner
  ) ERC20(_name, _symbol) {
    _decimals = _tokenDecimals;
    collateral = IERC20(_collateral);
    transferOwnership(_owner);
  }

  function decimals() public view virtual override(ERC20) returns (uint8) {
    return _decimals;
  }

  function deposit(
    address _recipient,
    uint256 _amountIn,
    uint256 _amountOut
  ) external onlyOwner {
    collateral.safeTransferFrom(msg.sender, address(this), _amountIn);
    _mint(_recipient, _amountOut);
  }

  function withdraw(
    address _recipient,
    uint256 _amountIn,
    uint256 _amountOut
  ) external onlyOwner {
    collateral.safeTransfer(_recipient, _amountOut);
    _burn(msg.sender, _amountIn);
  }
}
