// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface ILostTokenProvider {
    function getLostTokens(address tokenAddress) external;
}
