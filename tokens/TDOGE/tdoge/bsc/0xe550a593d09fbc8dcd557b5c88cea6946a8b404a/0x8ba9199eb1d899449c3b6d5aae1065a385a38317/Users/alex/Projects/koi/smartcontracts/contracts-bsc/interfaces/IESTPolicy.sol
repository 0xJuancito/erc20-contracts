// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
import "./ISTokenERC20.sol";

interface IESTPolicy {
    function getRebaseValues() external view returns (uint256, uint256, int256);
}