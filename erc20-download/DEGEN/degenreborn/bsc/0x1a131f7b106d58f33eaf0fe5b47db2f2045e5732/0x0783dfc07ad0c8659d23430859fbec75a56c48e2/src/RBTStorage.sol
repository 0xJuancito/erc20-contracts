// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract RBTStorage {
    mapping(address => bool) public minters;

    mapping(address => bool) public blocked;

    /// @dev gap for potential variable
    uint256[48] private _gap;
}
