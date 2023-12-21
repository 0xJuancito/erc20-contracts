// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;
pragma abicoder v2;

import "./DastraERC20.sol"
;
contract DastraERC20Mintable is DastraERC20 {
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 _decimals,
        uint256 cap,
        address trustedForwarder,
        address owner
    ) DastraERC20(name, symbol, initialSupply, _decimals, cap, trustedForwarder, owner) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}