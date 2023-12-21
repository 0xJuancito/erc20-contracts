// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct Set {
  bool exists;
  EnumerableSet.Bytes32Set list;
}

enum OpcodeType {
  VALUE,
  LENGTH,
  CONTAINS,
  INVERSE,
  ADD,
  SUB,
  MUL,
  DIV,
  EQ,
  GT,
  LT,
  NEQ,
  GTE,
  LTE,
  AND,
  OR,
  NAND
}

struct Opcode {
  OpcodeType opcode;
  bytes data;
}

struct ValueOpcode {
  uint256 value;
}

struct ContainsOpcode {
  bytes32[] keys;
}

struct InverseOpcode {
  Opcode value;
}

struct ArithmeticOperatorOpcode {
  Opcode[] values;
}

struct ComparatorOpcode {
  Opcode a;
  Opcode b;
}

struct GateOpcode {
  Opcode[] values;
}

interface IDB {
  /// @notice Adds a key value pair
  /// @param key The key to add
  /// @param value The value to add
  function add(bytes32 key, bytes32 value) external;

  /// @notice Adds a key value pair
  /// @param key The key to add
  /// @param value The value to add
  function add(bytes32 key, address value) external;

  /// @notice Sets a key value pair
  /// @param key The key to set
  /// @param value The value to set
  function set(bytes32 key, bytes32 value) external;

  /// @notice Sets a key value pair
  /// @param key The key to set
  /// @param value The value to set
  function set(bytes32 key, address value) external;

  /// @notice Adds a list of keys with a value pairs
  /// @param keys The keys to add
  /// @param value The value to add
  function add(bytes32[] calldata keys, bytes32 value) external;

  /// @notice Adds a list of keys with a value pairs
  /// @param keys The keys to add
  /// @param value The value to add
  function add(bytes32[] calldata keys, address value) external;

  /// @notice Adds a key with a list of value pairs
  /// @param key The key to add
  /// @param values The values to add
  function add(bytes32 key, bytes32[] calldata values) external;

  /// @notice Adds a key with a list of value pairs
  /// @param key The key to add
  /// @param values The values to add
  function add(bytes32 key, address[] calldata values) external;

  /// @notice Removes all pairs with the key and the key itself
  /// @param key The key to remove
  function removeKey(bytes32 key) external;

  /// @notice Removes all pairs with the value and the value itself
  /// @param value The value to remove
  function removeValue(bytes32 value) external;

  /// @notice Removes a pair
  /// @param key The key to remove
  /// @param value The value to remove
  function removePair(bytes32 key, bytes32 value) external;

  /// @notice Executes an opcode and its descendants against every value in the DB. It is effectively a custom VM, being able to do complex computation against all values in the DB
  /// @dev digest() is not meant to be used on-chain due to the high gas cost
  /// @param opcode The opcode to execute
  /// @return result The execution result for every value
  function digest(
    Opcode calldata opcode
  ) external view returns (bytes32[] memory result);

  /// @notice Gets the first value with the key
  /// @param key The key of the pair
  /// @return The bytes32 representation of the value
  function getValueB32(bytes32 key) external view returns (bytes32);

  /// @notice Gets the first value with the key
  /// @param key The key of the pair
  /// @return The bytes32 representation of the value
  function getValue(string memory key) external view returns (bytes32);

  /// @notice Gets the first value with the key
  /// @param key The key of the pair
  /// @return The address representation of the value
  function getAddressB32(bytes32 key) external view returns (address);

  /// @notice Gets the first value with the key
  /// @param key The key of the pair
  /// @return The address representation of the value
  function getAddress(string memory key) external view returns (address);

  /// @notice Gets the values with the key
  /// @param key The key of the pairs
  /// @return arr bytes32 representations of the values
  function getValues(bytes32 key) external view returns (bytes32[] memory arr);

  /// @notice Gets the keys with the value
  /// @param value The bytes32 value of the pairs
  /// @return arr The keys of the pairs
  function getKeys(bytes32 value) external view returns (bytes32[] memory arr);

  /// @notice Checks if the DB contains the key
  /// @param key The key to check against
  /// @return If the key exists
  function hasKey(bytes32 key) external view returns (bool);

  /// @notice Checks if the DB contains the value
  /// @param value The value to check against
  /// @return If the value exists
  function hasValue(bytes32 value) external view returns (bool);

  /// @notice Checks if the DB contains the pair
  /// @param key The key of the pair
  /// @param value The value of the pair
  /// @return If the pair exists
  function hasPair(bytes32 key, bytes32 value) external view returns (bool);
}
