// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {JonesGovernableVault} from "./JonesGovernableVault.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

abstract contract JonesOperableVault is JonesGovernableVault, ERC4626 {
    bytes32 public constant OPERATOR = bytes32("OPERATOR");

    modifier onlyOperator() {
        if (!hasRole(OPERATOR, msg.sender)) {
            revert CallerIsNotOperator();
        }

        _;
    }

    function addOperator(address _newOperator) external onlyGovernor {
        _grantRole(OPERATOR, _newOperator);

        emit OperatorAdded(_newOperator);
    }

    function removeOperator(address _operator) external onlyGovernor {
        _revokeRole(OPERATOR, _operator);

        emit OperatorRemoved(_operator);
    }

    function deposit(uint256 _assets, address _receiver) public virtual override onlyOperator returns (uint256) {
        return super.deposit(_assets, _receiver);
    }

    function mint(uint256 _shares, address _receiver) public virtual override onlyOperator returns (uint256) {
        return super.mint(_shares, _receiver);
    }

    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        onlyOperator
        returns (uint256)
    {
        return super.withdraw(_assets, _receiver, _owner);
    }

    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override
        onlyOperator
        returns (uint256)
    {
        return super.redeem(_shares, _receiver, _owner);
    }

    event OperatorAdded(address _newOperator);
    event OperatorRemoved(address _operator);

    error CallerIsNotOperator();
}
