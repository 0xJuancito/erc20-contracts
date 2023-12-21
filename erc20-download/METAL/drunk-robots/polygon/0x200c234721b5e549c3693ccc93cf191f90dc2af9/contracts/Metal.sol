// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solmate/src/tokens/ERC20.sol";
import "common-contracts/contracts/Blacklistable.sol";

contract Metal is ERC20, Blacklistable {
    constructor() ERC20("METAL", "METAL", 18) {
        _mint(msg.sender, 2750000000 ether);
    }

    function transfer(
        address to,
        uint amount
    ) public override notBlacklisted(msg.sender) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public override notBlacklisted(from) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}
