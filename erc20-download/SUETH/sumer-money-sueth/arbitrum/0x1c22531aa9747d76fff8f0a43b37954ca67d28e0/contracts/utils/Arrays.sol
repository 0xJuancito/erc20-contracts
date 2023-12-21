// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
    function find(uint256[] storage values, uint256 value)
        public
        view
        returns (uint256)
    {
        uint256 i = 0;
        while (values[i] != value) {
            i++;
        }
        return i;
    }

    function removeByValue(uint256[] storage values, uint256 value) public {
        uint256 length = values.length;
        for (uint256 i = find(values, value); i < length; ++i) {
            if (i < length - 1) {
                values[i] = values[i + 1];
            }
        }
        values.pop();
    }
}
