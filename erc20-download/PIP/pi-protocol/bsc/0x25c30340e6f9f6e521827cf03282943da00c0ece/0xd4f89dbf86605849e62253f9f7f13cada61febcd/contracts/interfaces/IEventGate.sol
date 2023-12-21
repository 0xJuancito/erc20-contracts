// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

interface IEventGate
{

    function handleZap(address sender, address recipient, uint256 amount) external returns(uint256);
    function enableGate(bool allow) external;
    function enabledGate() external view returns(bool);

}
