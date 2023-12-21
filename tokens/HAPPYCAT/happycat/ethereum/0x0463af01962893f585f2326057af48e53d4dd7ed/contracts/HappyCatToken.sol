// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HappyCatToken is ERC20, Ownable{
    address private _vault;
    mapping(address => bool) private _blacklists;
    mapping(address => bool) private _chargelists;
    mapping(address => bool) private _whitelists;

    event BlacklistSet(address account, bool isBlacklist);
    event ChargelistSet(address account, bool isChargelist);

    constructor(address vault_) ERC20("happycat", "happycat") {
        _vault = vault_;
        uint256 supply = 1 * 1e12 * 1e18;
        _mint(owner(), supply);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        amount = _transferCharge(owner, to, amount);
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        amount = _transferCharge(from, to, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transferCharge(address owner, address to, uint256 amount) internal returns(uint256) {
        require(!blacklistOf(owner) && !blacklistOf(to), "HappyCatToken: blacklist is denied");
        if (!whitelistOf(owner) && !whitelistOf(to)) {
            if (chargelistOf(owner) || chargelistOf(to)) {
                uint256 charge = amount * chargeRate() / 100;
                amount -= charge;
                _transfer(owner, vault(), charge);
            }
        }
        return amount;
    }

    function setBlacklists(address[] memory accounts, bool isBlacklist) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            _blacklists[account] = isBlacklist;
            emit BlacklistSet(account, isBlacklist);
        }
    }

    function setChargelists(address[] memory accounts, bool isChargelist) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            _chargelists[account] = isChargelist;
            emit ChargelistSet(account, isChargelist);
        }
    }

    function setWhitelist(address account, bool isWhitelist) external onlyOwner {
        _whitelists[account] = isWhitelist;
    }


    function blacklistOf(address account) public view returns(bool) {
        return _blacklists[account];
    }

    function chargelistOf(address account) public view returns(bool) {
        return _chargelists[account];
    }

    function whitelistOf(address account) public view returns(bool) {
        return _whitelists[account];
    }

    function chargeRate() public pure returns(uint256) {
        return 1;
    }

    function vault() public view returns(address) {
        return _vault;
    }

}