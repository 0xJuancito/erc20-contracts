// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// From https://github.com/maticnetwork/pos-portal/blob/83fd4965f071338fd22c8681cd160006c636e134/contracts/child/ChildToken/IChildToken.sol
interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}
