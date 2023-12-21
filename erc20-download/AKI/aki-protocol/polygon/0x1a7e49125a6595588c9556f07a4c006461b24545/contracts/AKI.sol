// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AKI is ERC20 {

    uint public constant TOTAL_SUPPLY = 2_000_000_000 * (10**18);
    
    constructor(address to_holder) ERC20("Aki Protocol", "AKI") {
        _mint(to_holder, TOTAL_SUPPLY);
    }
}
