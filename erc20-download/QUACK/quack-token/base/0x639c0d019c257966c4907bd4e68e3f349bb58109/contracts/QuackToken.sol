// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QuackToken is ERC20 {
    constructor(
        address _treasuryAddress,
        uint256 _treasuryAmount
    ) ERC20("Quack Token", "QUACK") {
        _mint(_treasuryAddress, _treasuryAmount);
    }
}
