// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBlacklist {
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    function blacklist(address[] calldata accounts) external;

    function unblacklist(address[] calldata accounts) external;

    function isPermitted(address account) external view returns (bool);
}
