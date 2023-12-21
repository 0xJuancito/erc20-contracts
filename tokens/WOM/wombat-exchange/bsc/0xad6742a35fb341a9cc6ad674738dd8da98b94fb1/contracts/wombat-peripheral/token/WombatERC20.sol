// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

contract WombatERC20 is ERC20('Wombat Token', 'WOM'), ERC20Permit('Wombat Token') {
    constructor(address _receipient, uint256 _totalSupply) {
        _mint(_receipient, _totalSupply);
    }
}
