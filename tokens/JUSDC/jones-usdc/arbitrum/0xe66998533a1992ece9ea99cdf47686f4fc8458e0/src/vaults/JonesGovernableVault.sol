// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

abstract contract JonesGovernableVault is AccessControl {
    bytes32 public constant GOVERNOR = bytes32("GOVERNOR");

    constructor(address _governor) {
        _grantRole(GOVERNOR, _governor);
    }

    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR, msg.sender)) {
            revert CallerIsNotGovernor();
        }
        _;
    }

    function updateGovernor(address _newGovernor) external onlyGovernor {
        _revokeRole(GOVERNOR, msg.sender);
        _grantRole(GOVERNOR, _newGovernor);

        emit GovernorUpdated(msg.sender, _newGovernor);
    }

    event GovernorUpdated(address _oldGovernor, address _newGovernor);

    error CallerIsNotGovernor();
}
