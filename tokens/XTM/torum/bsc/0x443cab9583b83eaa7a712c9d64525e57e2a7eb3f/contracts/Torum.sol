// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Torum is ERC20, Ownable {

    constructor() ERC20('Torum', 'XTM') {
        _mint(owner(), 800000000 * 1e18);
    }
}
