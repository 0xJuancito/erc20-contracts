// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

abstract contract ERC20Burnable {
    function burn(uint256 amount) public virtual {
        burnFrom(msg.sender, amount);
    }

    function burnFrom(address who, uint256 amount) public virtual;
}
