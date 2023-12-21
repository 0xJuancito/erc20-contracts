// contracts/MinieToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";
import "Lock.sol";

contract MonieToken is ERC20 {
    Lock public lock;
    uint256 supply_mine = 12 * 10**26;
    uint256 supply_com = 3.5 * 10**26;
    uint256 supply_t = 3 * 10**26;
    uint256 supply_f = 1 * 10**26;
    uint256 supply_s = 5 * 10**25;

    constructor(
        address _wallet_mine,
        address _wallet_com,
        address _wallet_t,
        address _wallet_f,
        address _wallet_s,
        address _lock
    ) ERC20("INFIBLUE WORLD", "MONIE") {
        lock = Lock(_lock);
        _mint(_wallet_mine, supply_mine);
        _mint(_wallet_com, supply_com);
        _mint(_wallet_t, supply_t);
        _mint(_wallet_f, supply_f);
        _mint(_wallet_s, supply_s);
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        address sender = msg.sender;
        uint256 current_locked = lock.check_lock(sender).current_locked;
        // lock will end by Nov 1st 2025, 36 months from Nov 1st 2022
        if (block.timestamp <= 1761980400 && current_locked > 0) {
            uint256 balance = balanceOf(sender);
            require(balance - amount >= current_locked);
        }
        _transfer(sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 current_locked = lock.check_lock(from).current_locked;
        // lock will end by Nov 1st 2025, 36 months from Nov 1st 2022
        if (block.timestamp <= 1761980400 && current_locked > 0) {
            uint256 balance = balanceOf(from);
            require(balance - amount >= current_locked);
        }

        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
}
