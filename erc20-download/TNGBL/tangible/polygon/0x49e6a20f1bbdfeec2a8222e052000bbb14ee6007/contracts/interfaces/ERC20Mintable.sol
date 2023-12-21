// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

abstract contract ERC20Mintable {
    function mint(uint256 amount) public virtual {
        mintFor(msg.sender, amount);
    }

    function mintFor(address who, uint256 amount) public virtual;
}
