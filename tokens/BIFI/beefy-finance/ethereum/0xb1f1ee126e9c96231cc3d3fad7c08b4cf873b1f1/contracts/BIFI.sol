// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BIFI is ERC20Upgradeable, ERC20PermitUpgradeable {
    
    function initialize(address _treasury) external initializer {
        __ERC20_init("Beefy", "BIFI");
        __ERC20Permit_init("Beefy");
        _mint(_treasury, 80_000 ether);
    }
}