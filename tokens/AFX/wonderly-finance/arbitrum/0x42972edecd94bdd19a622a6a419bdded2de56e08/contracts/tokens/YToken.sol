// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract YToken is ERC20Burnable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function maxTotalSupply() internal virtual view returns (uint256);
}
