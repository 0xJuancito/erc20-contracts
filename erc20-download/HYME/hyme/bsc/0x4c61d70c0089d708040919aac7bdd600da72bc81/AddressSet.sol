// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;


/**
 * Set implementation for storing and removing addresses with fixed gas lookups.
 */
library AddressSet {
  struct Data {
    address[] values; // contains unique addresses
    mapping (address => uint128) index; // address position in the list, values[0] has index 1, values[1] index 2 and so on
    uint128 count; // number of occupied slots, might be less than the values array length
  }

  /**
   * Adds an address if not already in the set.
   */
  function store (Data storage self, address value) public {
    // zero index means the address is not in the set
    if (self.index[value] == 0) {
      if (self.count < self.values.length)
        self.values[self.count] = value;
      else
        self.values.push(value); // extend the array if needed
      self.count++;
      // index is set to the position in the array + 1
      self.index[value] = self.count;
    }
  }

  /**
   * Utility function to move an address in the array and update its index.
   */
  function moveTo (Data storage self, address value, uint128 toIndex) private {
    self.index[value] = toIndex;
    self.values[toIndex-1] = value;
  }

  /**
   * Removes an address from the set.
   */
  function remove (Data storage self, address value) public {
    uint128 index = self.index[value];
    if (index > 0) {
        // in order to optimize space usage, the empty slot is replaced with the last one in the array
        uint128 lastIndex = uint128(self.count);
        address lastValue = self.values[lastIndex-1];
        moveTo(self, lastValue, index);
        // effective removal
        delete self.values[lastIndex-1];
        delete self.index[value];
        self.count--;
    }
  }

  /**
   * Fixed gas lookup for values in the set.
   */
  function contains (Data storage self, address value) public view returns (bool) {
    return self.index[value] > 0;
  }

  /**
   * Fixed gas lookup of positions of addresses in the set (position equals index).
   * Returns 0 if the address is not in the set.
   */
  function indexOf (Data storage self, address value) public view returns (uint128) {
    return self.index[value];
  }
}
