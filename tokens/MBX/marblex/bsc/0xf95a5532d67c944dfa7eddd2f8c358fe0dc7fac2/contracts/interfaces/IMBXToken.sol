// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IMBXToken {
    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);

    error FrozenAccount(address holder);

    function setFreeze(address holder, bool status) external returns (bool);

    function setFreezeMany(
        address[] calldata holders,
        bool[] calldata status
    ) external returns (bool);

    function transferMany(
        address[] calldata recipientList,
        uint256[] calldata amountList,
        uint256 burnAmount
    ) external returns (bool);

    function getNonce(address from) external view returns (uint256);

    function getRoleMembers(
        bytes32 role
    ) external view returns (address[] memory members);
}
