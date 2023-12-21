// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PbxToken is ERC20, ERC20Capped, ERC20Snapshot, AccessControl, Pausable {
    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);
    event SnapshotCreated(address indexed _account);
    event ContractPaused(address indexed _account);
    event ContractUnpaused(address indexed _account);

    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    uint256 private constant CAP = 1000000000 * 10**18;
    string private constant NAME = "Probinex Token";
    string private constant SYMBOL = "PBX";

    mapping(address => bool) private blacklisted;

    modifier notBlacklisted(address _account) {
        require(
            !blacklisted[_account],
            "Blacklistable: account is blacklisted"
        );
        _;
    }

    constructor(address _addr) ERC20(NAME, SYMBOL) ERC20Capped(CAP) {
        _grantRole(DEFAULT_ADMIN_ROLE, _addr);
        _grantRole(SNAPSHOT_ROLE, _addr);
        _grantRole(PAUSER_ROLE, _addr);
        _grantRole(BLACKLISTER_ROLE, _addr);
        _mint(_addr, CAP);
    }

    function isBlacklisted(address _account) external view returns (bool) {
        return blacklisted[_account];
    }

    function blacklist(address _account)
        external
        onlyRole(BLACKLISTER_ROLE)
    {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    function unBlacklist(address _account)
        external
        onlyRole(BLACKLISTER_ROLE)
    {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }

    function grantRoleString(string calldata role, address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        notBlacklisted(_msgSender())
        notBlacklisted(account)
    {
        _grantRole(keccak256(abi.encodePacked(role)), account);
    }

    function revokeRoleString(string calldata role, address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        notBlacklisted(_msgSender())
        notBlacklisted(account)
    {
        _revokeRole(keccak256(abi.encodePacked(role)), account);
    }

    function snapshot()
        external
        onlyRole(SNAPSHOT_ROLE)
        notBlacklisted(_msgSender())
    {
        _snapshot();
        emit SnapshotCreated(_msgSender());
    }

    function pause() external onlyRole(PAUSER_ROLE) notBlacklisted(_msgSender()) {
        _pause();
        emit ContractPaused(_msgSender());
    }

    function unpause()
        external
        onlyRole(PAUSER_ROLE)
        notBlacklisted(_msgSender())
    {
        _unpause();
        emit ContractUnpaused(_msgSender());
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Snapshot)
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        override(ERC20Capped, ERC20)
        notBlacklisted(account)
        notBlacklisted(_msgSender())
    {
        require(
            ERC20.totalSupply() + amount <= cap(),
            "ERC20Capped: cap exceeded"
        );
        super._mint(account, amount);
    }
}
