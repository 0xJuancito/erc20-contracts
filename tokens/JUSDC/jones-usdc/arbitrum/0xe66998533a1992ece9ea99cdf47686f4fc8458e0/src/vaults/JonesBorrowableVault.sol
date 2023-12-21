// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {JonesGovernableVault} from "./JonesGovernableVault.sol";
import {IJonesBorrowableVault} from "../interfaces/IJonesBorrowableVault.sol";
import {Pausable} from "../common/Pausable.sol";

abstract contract JonesBorrowableVault is JonesGovernableVault, ERC4626, IJonesBorrowableVault, Pausable {
    bytes32 public constant BORROWER = bytes32("BORROWER");

    modifier onlyBorrower() {
        if (!hasRole(BORROWER, msg.sender)) {
            revert CallerIsNotBorrower();
        }
        _;
    }

    function addBorrower(address _newBorrower) external onlyGovernor {
        _grantRole(BORROWER, _newBorrower);

        emit BorrowerAdded(_newBorrower);
    }

    function removeBorrower(address _borrower) external onlyGovernor {
        _revokeRole(BORROWER, _borrower);

        emit BorrowerRemoved(_borrower);
    }

    function togglePause() external onlyGovernor {
        if (paused()) {
            _unpause();
            return;
        }

        _pause();
    }

    function borrow(uint256 _amount) external virtual onlyBorrower whenNotPaused returns (uint256) {
        IERC20(asset()).transfer(msg.sender, _amount);

        emit AssetsBorrowed(msg.sender, _amount);

        return _amount;
    }

    function repay(uint256 _amount) external virtual onlyBorrower returns (uint256) {
        IERC20(asset()).transferFrom(msg.sender, address(this), _amount);

        emit AssetsRepayed(msg.sender, _amount);

        return _amount;
    }

    event BorrowerAdded(address _newBorrower);
    event BorrowerRemoved(address _borrower);
    event AssetsBorrowed(address _borrower, uint256 _amount);
    event AssetsRepayed(address _borrower, uint256 _amount);

    error CallerIsNotBorrower();
}
