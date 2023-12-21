// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.7;

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipChanged(address from, address to);

    constructor() {
        owner = msg.sender;
        emit OwnershipChanged(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // owner can give super-rights to someone
    function giveOwnership(address user) external onlyOwner {
        require(user != address(0), "User renounceOwnership");
        newOwner = user;
    }

    // new owner need to accept
    function acceptOwnership() external {
        require(msg.sender == newOwner, "Only NewOwner");
        emit OwnershipChanged(owner, newOwner);
        owner = msg.sender;
        delete newOwner;
    }
}
