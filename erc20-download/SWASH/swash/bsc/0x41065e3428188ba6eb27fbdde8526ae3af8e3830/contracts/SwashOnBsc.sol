// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC677.sol";

contract SWASHOnBsc is Ownable, ERC677, ERC20Permit, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event LogSwapin(bytes32 indexed txhash, address indexed account, uint amount);
    event LogSwapout(address indexed account, address indexed bindaddr, uint amount);

    // flag to enable/disable swapout vs vault.burn so multiple events are triggered
    bool private _vaultOnly;

    constructor() ERC20("Swash Token", "SWASH") ERC20Permit("SWASH") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _vaultOnly = false;
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        setAdmin(newOwner);
        revokeRole(DEFAULT_ADMIN_ROLE, owner());
        Ownable.transferOwnership(newOwner);
    }

    function setVaultOnly(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _vaultOnly = enabled;
    }

    function setMinter(address wallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, wallet);
    }

    function setAdmin(address wallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEFAULT_ADMIN_ROLE, wallet);
    }

    function revokeAdmin(address wallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(owner() != wallet, "Can not revoke owner");
        revokeRole(DEFAULT_ADMIN_ROLE, wallet);
    }

    function revokeMinter(address wallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, wallet);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(to, amount);
        return true;
    }

    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        require(from != address(0), "address(0x0)");
        _burn(from, amount);
        return true;
    }

    function Swapin(bytes32 txhash, address account, uint256 amount) public onlyRole(MINTER_ROLE) returns (bool) {
        _mint(account, amount);
        emit LogSwapin(txhash, account, amount);
        return true;
    }

    function Swapout(uint256 amount, address bindaddr) public returns (bool) {
        require(!_vaultOnly, "onlyAuth");
        require(bindaddr != address(0), "address(0x0)");
        _burn(msg.sender, amount);
        emit LogSwapout(msg.sender, bindaddr, amount);
        return true;
    }
}
