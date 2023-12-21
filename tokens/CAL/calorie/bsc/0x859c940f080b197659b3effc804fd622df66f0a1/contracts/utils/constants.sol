// SPDX-License-Identifier: UNLICENSED

// Author: TrejGun
// Email: trejgun@gemunion.io
// Website: https://gemunion.io/

pragma solidity ^0.8.13;

bytes32 constant EARN_UPGRADE = keccak256("EARN_UPGRADE");
bytes32 constant TIME_UPGRADE = keccak256("TIME_UPGRADE");

bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
bytes32 constant METADATA_ROLE = keccak256("METADATA_ROLE");
bytes32 constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");
bytes32 constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

bytes32 constant TEMPLATE_ID = keccak256("TEMPLATE_ID");
bytes32 constant RARITY = keccak256("RARITY");

bytes4 constant IERC721_SIMPLE_ID = 0xdc662ff6;
bytes4 constant IERC721_GRADE_ID = 0x381b3743;
bytes4 constant IERC721_RANDOM_ID = 0x32034d27;
bytes4 constant IERC721_MYSTERY_ID = 0xf0f47261;

bytes4 constant IERC1363_ID = 0xb0202a11;
bytes4 constant IERC1363_RECEIVER_ID = 0x88a7ca5c;
bytes4 constant IERC1363_SPENDER_ID = 0x7b04a2d0;
bytes4 constant IERC4906_ID = 0x49064906;
bytes4 constant IERC4907_ID = 0xad092b5c;