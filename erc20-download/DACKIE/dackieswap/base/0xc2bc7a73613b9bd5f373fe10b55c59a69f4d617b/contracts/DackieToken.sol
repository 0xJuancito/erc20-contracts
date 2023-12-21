// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DackieToken is ERC20 {

    constructor(
        address _treasuryAddress,
        uint256 _treasuryAmount
    ) ERC20("Dackie Token", "DACKIE") {
        _mint(_treasuryAddress, _treasuryAmount);
    }
}
