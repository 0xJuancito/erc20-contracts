// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;


/// @title Utils
library Utils {
    function ensureNotZero(address addr) internal pure returns(address) {
        require(addr != address(0), "ZERO_ADDRESS");
        return addr;
    }

    modifier onlyNotZeroAddress(address addr) {
        require(addr != address(0), "ZERO_ADDRESS");
        _;
    }
}
