// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IERC677Receiver {
    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes calldata _data
    ) external;
}
