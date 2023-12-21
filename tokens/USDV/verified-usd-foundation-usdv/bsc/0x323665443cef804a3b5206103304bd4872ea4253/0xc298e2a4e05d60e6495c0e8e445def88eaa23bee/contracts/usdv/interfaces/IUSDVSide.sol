// SPDX-License-Identifier: LZBL-1.1
// Copyright 2023 LayerZero Labs Ltd.
// You may obtain a copy of the License at
// https://github.com/LayerZero-Labs/license/blob/main/LICENSE-LZBL-1.1

pragma solidity ^0.8.0;

import "./IUSDV.sol";

interface IUSDVSide is IUSDV {
    event Reminting(bytes32 _guid, Delta[] deltas, uint64 remintFee);

    function remint(
        uint32 _surplusColor,
        uint64 _surplusAmount,
        uint32[] calldata _deficits,
        uint64 _feeCap,
        bytes calldata _extraOptions,
        MessagingFee calldata _msgFee,
        address payable _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt);

    function quoteRemintFee(
        uint32 _numDeficits,
        bytes calldata _extraOptions,
        bool _useLZToken
    ) external view returns (uint nativeFee, uint lzTokenFee);
}
