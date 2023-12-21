// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

bytes32 constant DEFAULT_ADMIN = 0x00;
bytes32 constant BANNED = "banned";
bytes32 constant MODERATOR = "moderator";
bytes32 constant ANY_ROLE = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
bytes32 constant BRIDGE_CONTRACT = keccak256("BRIDGE_CONTRACT");
bytes32 constant BRIDGE_ROLE_MGR = keccak256("BRIDGE_ROLE_MGR");
