// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IA3SToken {
    function mint(address to, uint256 amount) external;
    function bridgeMint(address owner, uint256 amount) external returns(bool);
    function bridgeBurn(address owner, uint256 amount) external returns(bool);
    function setBridgeAccess(address bridgeAddr) external;
}
