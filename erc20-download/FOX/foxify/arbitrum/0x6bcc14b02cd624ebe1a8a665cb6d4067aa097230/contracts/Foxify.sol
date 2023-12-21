// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Foxify is ERC20, ERC20Burnable {
    constructor(
        string memory name_,
        string memory symbol_,
        address recipient_,
        uint256 supply_
    ) ERC20(name_, symbol_) {
        _mint(recipient_, supply_);
    }
}
