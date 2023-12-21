// SPDX-License-Identifier: LZBL-1.1
// Copyright 2023 LayerZero Labs Ltd.
// You may obtain a copy of the License at
// https://github.com/LayerZero-Labs/license/blob/main/LICENSE-LZBL-1.1

pragma solidity 0.8.19;

import "hardhat-deploy/solc_0.8/proxy/Proxied.sol";
import "./USDVBase.sol";
import "./interfaces/IUSDVMain.sol";
import {IVaultManager} from "../vault/interfaces/IVaultManager.sol";

contract USDVMain is IUSDVMain, Proxied, USDVBase {
    function initialize(address _owner, address _foundation) public proxied initializer {
        __USDVBase_init(_owner, _foundation);
    }

    /// @dev if after recolor, amount supplied is greater than float, the excess will be ignored (avoid reminting same color)
    function remint(
        uint32 _surplusColor,
        uint64 _surplusAmount,
        uint32[] calldata _deficits,
        uint64 _feeCap
    ) external whenNotPaused {
        (uint64 remintFee, Delta[] memory deltas) = _remint(_surplusColor, _surplusAmount, _deficits, _feeCap);
        address vaultManager = getRole(Role.VAULT);

        // charge remint fee
        if (remintFee > 0) {
            transfer(vaultManager, remintFee);
        }

        // minterOwner is VaultManager here
        IVaultManager(vaultManager).remint(deltas, remintFee);

        emit Reminted(deltas, remintFee);
    }

    /// @dev whenNotPaused checked in _sendAck
    function remintAck(
        Delta[] calldata _deltas,
        uint32 _feeColor,
        uint64 _feeAmount,
        uint64 _feeTheta
    ) external whenNotPaused onlyRole(Role.MESSAGING) {
        address vaultManager = getRole(Role.VAULT);
        // the fee is credited to the vault
        if (_feeAmount > 0) {
            _sendAck(vaultManager, _feeColor, _feeAmount, _feeTheta);
        }
        // apply the changes to the vault
        IVaultManager(vaultManager).remint(_deltas, _feeAmount);

        emit Reminted(_deltas, _feeAmount);
    }
}
