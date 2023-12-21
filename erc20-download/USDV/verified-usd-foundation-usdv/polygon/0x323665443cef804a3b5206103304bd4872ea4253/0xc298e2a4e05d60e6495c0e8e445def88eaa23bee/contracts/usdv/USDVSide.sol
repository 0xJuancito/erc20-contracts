// SPDX-License-Identifier: LZBL-1.1
// Copyright 2023 LayerZero Labs Ltd.
// You may obtain a copy of the License at
// https://github.com/LayerZero-Labs/license/blob/main/LICENSE-LZBL-1.1

pragma solidity 0.8.19;

import "hardhat-deploy/solc_0.8/proxy/Proxied.sol";
import "./USDVBase.sol";
import "./interfaces/IUSDVSide.sol";

contract USDVSide is IUSDVSide, Proxied, USDVBase {
    function initialize(address _owner, address _foundation) public proxied initializer {
        __USDVBase_init(_owner, _foundation);
    }

    function remint(
        uint32 _surplusColor,
        uint64 _surplusAmount,
        uint32[] calldata _deficits,
        uint64 _feeCap,
        bytes calldata _extraOptions,
        MessagingFee calldata _msgFee,
        address payable _refundAddress
    ) external payable whenNotPaused returns (MessagingReceipt memory msgReceipt) {
        (uint64 remintFee, Delta[] memory deltas) = _remint(_surplusColor, _surplusAmount, _deficits, _feeCap);

        // charge remint fee and send cross chain
        (uint32 feeColor, uint64 feeTheta) = remintFee == 0 ? (0, 0) : _send(remintFee);

        msgReceipt = IMessaging(getRole(Role.MESSAGING)).remint{value: msg.value}(
            deltas,
            feeColor,
            remintFee,
            feeTheta,
            _extraOptions,
            _msgFee,
            _refundAddress
        );

        emit Reminting(msgReceipt.guid, deltas, remintFee);
    }

    // @dev race condition may create a longer payload. so should quote with the buffer
    function quoteRemintFee(
        uint32 _numDeficits,
        bytes calldata _extraOptions,
        bool _useLZToken
    ) external view returns (uint nativeFee, uint lzTokenFee) {
        Delta[] memory deltas = new Delta[](_numDeficits + 1);
        return IMessaging(getRole(Role.MESSAGING)).quoteRemintFee(deltas, _extraOptions, _useLZToken);
    }
}
