// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";

interface IVC is IERC20 {
    function notifyMigration(uint128 n) external;
    function dispense() external returns (uint256);
    function emissionRate() external view returns (uint256);
}
