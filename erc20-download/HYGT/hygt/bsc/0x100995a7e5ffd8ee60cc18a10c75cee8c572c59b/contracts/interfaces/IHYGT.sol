// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.19;

import "./IERC20.sol";

interface IHYGT is IERC20 {

    function maxTotalSupply() external view returns (uint256);

    function mint(address to, uint256 amount) external returns (bool);

    function burn(uint256 amount) external returns (bool);

    function burnFrom(address from, uint256 amount) external returns (bool);

    function delegate(address delegatee) external;

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
}