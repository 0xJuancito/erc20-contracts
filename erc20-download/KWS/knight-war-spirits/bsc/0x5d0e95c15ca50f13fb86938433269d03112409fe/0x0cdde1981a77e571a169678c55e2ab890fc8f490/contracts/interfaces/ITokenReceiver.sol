// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface ITokenReceiver {
  function tokensReceived(
    address operator,
    address from,
    address to,
    uint256 amount
  ) external;
}