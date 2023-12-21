// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BTAFToken is ERC20PresetMinterPauser, Ownable {
    string constant _name = "BTAF";
    string constant _symbol = "BTAF";
    uint256 constant _initialSupply = 200_000_000 * 10**18;

    constructor() ERC20PresetMinterPauser(_name, _symbol) {
        super.mint(msg.sender, _initialSupply);
    }
}
