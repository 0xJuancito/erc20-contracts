pragma experimental ABIEncoderV2;
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

library StringLib {
  /// @notice Convert a uint value to its decimal string representation
  // solium-disable-next-line security/no-assign-params
  function toString(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
      return '0';
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len - 1;
    while (_i != 0) {
      bstr[k--] = bytes1(uint8(48 + (_i % 10)));
      _i /= 10;
    }
    return string(bstr);
  }

  /// @notice Convert a bytes32 value to its hex string representation
  function toString(bytes32 _value) internal pure returns (string memory) {
    bytes memory alphabet = '0123456789abcdef';

    bytes memory str = new bytes(32 * 2 + 2);
    str[0] = '0';
    str[1] = 'x';
    for (uint256 i = 0; i < 32; i++) {
      str[2 + i * 2] = alphabet[uint256(uint8(_value[i] >> 4))];
      str[3 + i * 2] = alphabet[uint256(uint8(_value[i] & 0x0f))];
    }
    return string(str);
  }

  /// @notice Convert an address to its hex string representation
  function toString(address _addr) internal pure returns (string memory) {
    bytes32 value = bytes32(uint256(_addr));
    bytes memory alphabet = '0123456789abcdef';

    bytes memory str = new bytes(20 * 2 + 2);
    str[0] = '0';
    str[1] = 'x';
    for (uint256 i = 0; i < 20; i++) {
      str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
      str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
    }
    return string(str);
  }

  function toString(bytes memory input) internal pure returns (string memory) {
    return string(input);
  }
}
