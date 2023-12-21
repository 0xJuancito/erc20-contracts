// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BMAX is ERC20Burnable, Ownable {
    address constant ADMIN = 0x15d6e49B81ab4c095cee2B9eF5A13b86493F4230;

    constructor() ERC20("BMAX", "Bitrue Asset Management Token") {
        _mint(ADMIN, 50 * 1e8 * 1e18);
        _transferOwnership(ADMIN);
    }

    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }
}
