// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

contract ATAToken is ERC20PresetMinterPauser {
    using SafeMath for uint256;

    constructor(uint256 initialSupply) public ERC20PresetMinterPauser('Automata', 'ATA') {
        _mint(msg.sender, initialSupply);
    }
}