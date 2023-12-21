// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EmeldiGroup is ERC20 {

    // Initially there are 300 mio tokens pre-minted.
    uint256 public constant SUPPLY_BASE = 300_000_000;

    address immutable private owner;

    constructor() ERC20("EMG SuperApp", "EMGS") {
        owner = msg.sender;
        // pre-mint the supply
        _mint(msg.sender, SUPPLY_BASE * 10**decimals());
    }

    // fallback, accept ETH
    receive() external payable {
        payable(owner).transfer(msg.value);
    }

}