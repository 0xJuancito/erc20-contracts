// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IRoleManager {


    function hasRole(bytes32 role, address account) external view returns (bool);

}
