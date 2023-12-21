// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {StringUtils} from '../base/utils/StringUtils.sol';

contract UtilsMock {
  using StringUtils for string;
  using StringUtils for bytes32;

  function stringToBytes32(string memory _string)
    external
    pure
    returns (bytes32 result)
  {
    result = _string.stringToBytes32();
  }

  function bytes32ToString(bytes32 _bytes32)
    external
    pure
    returns (string memory)
  {
    return _bytes32.bytes32ToString();
  }
}
