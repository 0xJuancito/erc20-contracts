// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract PalmToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("PALM", "PALM") {
        _mint(msg.sender, 17700000e18);
    }
}
