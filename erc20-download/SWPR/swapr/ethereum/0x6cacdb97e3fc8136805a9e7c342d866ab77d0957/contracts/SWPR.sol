pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title SWPR
 * @dev SWPR token contract
 * @author Federico Luzzi - <fedeluzzi00@gmail.com>
 * SPDX-License-Identifier: GPL-3.0
 */
contract SWPR is ERC20Burnable {
    constructor(address _ownerAddress) ERC20("Swapr", "SWPR") {
        _mint(_ownerAddress, 100000000 ether);
    }
}
