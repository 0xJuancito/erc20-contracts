// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBaseToken {
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
    function withdrawToken(address _token, address _account, uint256 _amount) external;
}
