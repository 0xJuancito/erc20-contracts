// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface ILocker {
    /**
     * @dev Fails if transaction is not allowed. Otherwise returns the penalty.
     * @return a bool and a uint256, bool clarifying the penalty applied, and uint256 the penaltyOver1000
     */
    function lockOrGetPenalty(address source, address dest) external returns (bool, uint256);
}

