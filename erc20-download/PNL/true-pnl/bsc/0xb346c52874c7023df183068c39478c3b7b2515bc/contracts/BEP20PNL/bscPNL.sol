//SPDX-License-Identifier: MIT

/**

This  is an official BSC version of TruePNL $PNL token: 0x9fc8f0ca1668e87294941b7f627e9c15ea06b459 (ERC20).
Visit truepnl.com to learn more.

**/
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract PNL is ERC20PresetMinterPauser {
    constructor(uint256 supply) ERC20PresetMinterPauser("PNL", "TruePNL") {
        _mint(msg.sender, supply);
    }
}
