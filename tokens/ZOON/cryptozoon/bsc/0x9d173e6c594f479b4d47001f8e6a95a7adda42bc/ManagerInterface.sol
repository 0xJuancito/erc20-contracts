// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

interface ManagerInterface {
    function evolvers(address _address) external view returns (bool);

    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function xBattle() external view returns (uint256);

    function priceEgg() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function feeMarket() external view returns (uint256);

    function feeSpawn() external view returns (uint256);

    function feeAddress() external view returns (address);
}