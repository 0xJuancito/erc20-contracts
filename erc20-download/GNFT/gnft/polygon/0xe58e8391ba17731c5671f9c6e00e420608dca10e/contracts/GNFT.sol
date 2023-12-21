// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OwnableToken.sol";

contract GNFT is OwnableToken {
  constructor() OwnableToken("GNFT", "GNFT") {}
}