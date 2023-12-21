// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract OtxExchange is ERC20, Ownable, ERC20Permit {
    mapping(address => bool) private blacklisted;
    uint256 private constant INITIAL_SUPPLY = 550 * 10**6 * 10**18; // 550 million tokens with 18 decimals
    uint256 private constant MAX_MINTABLE = 550 * 10**6 * 10**18;  // 550 million tokens with 18 decimals
    uint256 private totalMinted = 0;

    constructor()
    ERC20("OtxExchange", "OTX")
    ERC20Permit("OtxExchange")
    {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalMinted + amount <= MAX_MINTABLE, "OTX: Exceeds max mintable limit");
        totalMinted += amount;
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function blacklistAddress(address _address, bool _blacklisted) public onlyOwner {
        require(_address != owner(), "OTX: Owner cannot be blacklisted");
        blacklisted[_address] = _blacklisted;
    }

    function isBlacklisted(address _address) public view returns (bool) {
        return blacklisted[_address];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!blacklisted[from], "OTX: Sender is blacklisted!");
        require(!blacklisted[to], "OTX: Receiver is blacklisted!");
    }
}
