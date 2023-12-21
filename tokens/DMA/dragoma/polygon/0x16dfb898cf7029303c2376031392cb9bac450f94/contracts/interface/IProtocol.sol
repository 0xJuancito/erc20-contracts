// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


interface IProtocol {

    function inWhiteList(address _account) external view returns(bool);

    function getAirdropPortion(address _account) external view returns(uint256);
}
