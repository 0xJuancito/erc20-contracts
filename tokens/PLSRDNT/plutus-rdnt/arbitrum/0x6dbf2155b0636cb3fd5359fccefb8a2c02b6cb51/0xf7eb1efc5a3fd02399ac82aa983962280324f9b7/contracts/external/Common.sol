// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ITokenMinterMulti is IERC20 {
  function mint(address, uint256) external;

  function burn(address, uint256) external;

  function updateMinter(address _minter, bool _isActive) external;
}

interface ITokenMinter {
  function mint(address, uint256) external;

  function burn(address, uint256) external;
}

interface IErrors {
  error FAILED(string);
  error UNAUTHORIZED();
}
