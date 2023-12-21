// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./GatedERC20.sol";

contract DarkMagic is GatedERC20("Dark Magic", "DMAGIC")
{
    constructor()
    {
        _mint(msg.sender, 4000000 ether);
        // 4000000 
        // ether);
    }
}
