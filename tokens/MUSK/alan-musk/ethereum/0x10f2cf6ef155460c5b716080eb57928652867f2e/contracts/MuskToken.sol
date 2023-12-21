//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

contract MuskToken is ERC20Burnable {
    constructor(address account, uint256 initialSupply) ERC20('Musk', 'MUSK') {
        _mint(account, initialSupply);
    }
}
