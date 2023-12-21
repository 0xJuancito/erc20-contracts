// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc20.sol";
import "ownable.sol";

contract hiveWaterToken is ERC20, Ownable {

    constructor() public ERC20("hiveWATER Token", "hiveWATER") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}