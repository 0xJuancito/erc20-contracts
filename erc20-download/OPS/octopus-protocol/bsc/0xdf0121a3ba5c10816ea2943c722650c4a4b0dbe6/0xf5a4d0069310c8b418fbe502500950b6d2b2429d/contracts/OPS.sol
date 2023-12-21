// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OPS is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    string internal constant NAME = "Octopus Protocol";
    string internal constant SYMBOL = "OPS";
    uint8 internal constant DECIMALS = 18;

    uint256 internal constant TOTAL_SUPPLY = 150000000 * 1e18;

    function initialize() public initializer {
        __ERC20_init(NAME, SYMBOL);
        _mint(msg.sender, TOTAL_SUPPLY);
        __Ownable_init();
    }
}
