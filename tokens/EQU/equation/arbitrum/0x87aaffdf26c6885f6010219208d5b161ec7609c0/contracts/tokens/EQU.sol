// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.21;

import "./MultiMinter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract EQU is ERC20, ERC20Capped, ERC20Permit, MultiMinter {
    constructor() ERC20("Equation", "EQU") ERC20Permit("Equation Protocol") ERC20Capped(10_000_000e18) {}

    function mint(address account, uint256 amount) public onlyMinter {
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}
