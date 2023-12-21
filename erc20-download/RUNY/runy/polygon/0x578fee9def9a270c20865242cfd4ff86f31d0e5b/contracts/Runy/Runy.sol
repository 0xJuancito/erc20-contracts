// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IRuny.sol";
import "../base/WithRunyStakingGuard.sol";

/**
 * @title Runy token.
 */
contract Runy is IRuny, ERC20, Ownable, WithRunyStakingGuard {
    // MAX_SUPPLY, immutable 16.8 billion RUNYs
    uint256 public constant MAX_SUPPLY = 16_800_000_000 ether;
    mapping(address => bool) public blacklisted;

    constructor() ERC20("Runy", "Runy") {
        _mint(
            address(0x71C9235203e4EdF1846c7F5DEd99216eB7452097), // Bridge Token Hub
            1_000_000_000 ether
        );
        _mint(
            address(0x9d7aFe4C20e31940C49e11BCA465b57E53d8F8F7), // Initial Liquitidy
            2_000_000 ether
        );
        _mint(
            address(0xE3E4EdAaB4101862d9B52706D8D4fBDb6550Cc89), // Liquidity Reserve
            295_000_000 ether
        );
        _mint(
            address(0x375C74d1F41ABed5F129F6b112c20Dc496a64088), // Shop Runiverse
            100_000_000 ether
        );
        _mint(
            address(0x4839b53Ce80273192eAE8D4092A8F2503C7cB603), // Marketing
            100_000_000 ether
        );
        _mint(
            address(0x9B378BdCce82bD238a370b97BDaCc07400E10EE2), // AR Airdrop
            3_000_000 ether
        );
    }

    function mint(address to, uint256 amount) external onlyRunyStakingOperator {
        require(totalSupply() + amount <= MAX_SUPPLY, "max_supply_reached");
        _mint(to, amount);
    }

    function blacklist(address addr) external onlyOwner {
        blacklisted[addr] = true;
    }

    function unBlacklist(address addr) external onlyOwner {
        blacklisted[addr] = false;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(!blacklisted[sender], "sender_blacklisted");
        require(!blacklisted[recipient], "recipient_blacklisted");
        super._transfer(sender, recipient, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
