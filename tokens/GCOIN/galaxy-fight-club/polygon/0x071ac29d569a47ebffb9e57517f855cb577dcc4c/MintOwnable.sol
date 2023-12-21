// SPDX-License-Identifier: MIT
   
pragma solidity ^0.8.11;

contract MintOwnable {
    address public minter;

    event MinterSet(address minter);

    constructor() { 
        minter = msg.sender; 
    }

    modifier onlyMinter {
        require(msg.sender == minter, "You are not authorizated to call this function");
        _;
    }

    function setMinter(address address_) external onlyMinter {
        require(address_ != address(0x0), "the minter can not be set to the burn address");
        minter = address_;

        emit MinterSet(minter);
    }

    function renounceMinter() external onlyMinter {
        minter = address(0x0);
    }
}