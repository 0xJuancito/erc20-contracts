// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20Chainable {
    event CrossIn(
        bytes32 indexed round,
        uint256 amount
    );
}