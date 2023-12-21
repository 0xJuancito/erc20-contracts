// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface SwapContractInterface {

    function getPair() external view returns(address);

    function getRouter() external view returns(address);

    function swap(uint256 _amount) external;
}
