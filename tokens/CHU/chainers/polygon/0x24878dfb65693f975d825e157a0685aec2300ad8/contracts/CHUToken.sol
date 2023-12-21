// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CHUToken is ERC20 {
    bool private _paused;
    uint8 private _decimals;

    address private _owner;

    mapping(address => bool) public blacklisted; 

    modifier whenActive {
        require(!_paused, "CHU: paused");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == _owner, "CHU: msg.sender in not an owner");
        _;
    }

    modifier checkBlacklist(address account) {
        require(!blacklisted[account], "CHU: token transfer with blacklisted account");
        _;
    }

    constructor(uint8 _setupDecimals) ERC20("CHU", "CHU") {
        _owner = msg.sender;

        _decimals = _setupDecimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function burn(
        uint256 amount
    ) 
        external 
        onlyOwner
    {
        _burn(msg.sender, amount);
    }

    function addToBlacklist(address account) external onlyOwner {
        require(account != _owner, "CHU: owner cannot be blacklisted");

        blacklisted[account] = true;
    }

    function removeFromBlacklist(address account) external onlyOwner {
        blacklisted[account] = false;
    }

    function pause() external onlyOwner {
        _paused = true;
    }

    function unpause() external onlyOwner {
        _paused = false;
    }

    function approve(address spender, uint256 amount) public virtual override whenActive returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual override whenActive checkBlacklist(owner) checkBlacklist(spender) {
        require(owner != _owner, "CHU: token owner funds approval");
        super._approve(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenActive checkBlacklist(from) checkBlacklist(to) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function isPaused() public view returns (bool) {
        return _paused;
    }
}