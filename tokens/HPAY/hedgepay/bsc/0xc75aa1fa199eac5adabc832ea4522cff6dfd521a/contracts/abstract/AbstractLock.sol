// SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

abstract contract Lock  {
    bool private unlocked = true;

    modifier lock() {
        require(unlocked == true, "Lock: LOCKED");
        unlocked = false;
        _;
        unlocked = true;
    }
}