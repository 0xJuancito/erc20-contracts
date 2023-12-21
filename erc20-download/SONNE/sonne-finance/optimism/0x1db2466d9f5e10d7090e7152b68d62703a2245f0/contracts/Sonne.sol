//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sonne is ERC20 {
    constructor(address account) ERC20("Sonne", "SONNE") {
        _mint(account, 100_000_000e18);
    }
}
