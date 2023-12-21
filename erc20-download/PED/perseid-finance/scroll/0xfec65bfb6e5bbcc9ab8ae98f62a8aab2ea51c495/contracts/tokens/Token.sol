// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is Ownable, ERC20 {

    uint256 public constant INITIAL_SUPPLY = 50000000 * 1e18;

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol){
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
