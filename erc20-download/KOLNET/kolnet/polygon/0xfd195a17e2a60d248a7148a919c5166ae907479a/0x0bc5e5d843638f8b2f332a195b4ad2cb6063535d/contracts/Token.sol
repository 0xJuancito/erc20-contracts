// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./LosslessERC20.sol";

contract Token is 
        Initializable, 
        ContextUpgradeable, 
        UUPSUpgradeable, 
        AccessControlUpgradeable, 
        ERC20Upgradeable,
        ERC20PausableUpgradeable,
        ERC20BurnableUpgradeable, 
        ERC20SnapshotUpgradeable,
        LosslessERC20
    {
    string constant SYMBOL  = 'KOLnet';
    string constant NAME    = 'KOLnet Token';

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SNAPSHOT_MANAGER_ROLE = keccak256("SNAPSHOT_MANAGER_ROLE");
    bytes32 public constant PAUSE_MANAGER_ROLE = keccak256("PAUSE_MANAGER_ROLE");
    bytes32 public constant WHITELISTED_FROM_ROLE = keccak256("WHITELISTED_FROM_ROLE");
    bytes32 public constant WHITELISTED_SENDER_ROLE = keccak256("WHITELISTED_SENDER_ROLE");
    bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");
    bytes32 public constant TXFEE_MANAGER_ROLE = keccak256("TXFEE_MANAGER_ROLE");
    bytes32 public constant TXFEE_WHITELISTED_ROLE = keccak256("TXFEE_WHITELISTED_ROLE");


    uint256 public txFee; //100% fee = 1e18
    address public txFeeBeneficiary;

    constructor() initializer{
        // Here we need to initialize storage to not allow anyone to use this implementation-only contract.
        // This contract should only be used via Proxy.
        __Token_init("", "", address(0), address(0), 0, ILosslessController(address(0)));
        renounceRole(MINTER_ROLE, _msgSender());        
        renounceRole(PAUSE_MANAGER_ROLE, _msgSender());        
        renounceRole(SNAPSHOT_MANAGER_ROLE, _msgSender());        
        renounceRole(TXFEE_MANAGER_ROLE, _msgSender());        
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
    
    function initialize(address _admin, address _recoveryAdmin, uint256 _timelockPeriod, ILosslessController _lossless) public virtual initializer {
        require(_admin != address(0), "admin required for Lossless");
        require(_recoveryAdmin != address(0), "recoveryAdmin required for Lossless");
        require(address(_lossless) != address(0), "lossless controller required for Lossless");
        require(_timelockPeriod >= 86400, "timelockPeriod should be greater than 24 hrs");

        __Token_init(NAME, SYMBOL, _admin, _recoveryAdmin, _timelockPeriod, _lossless);
    }

    function __Token_init(string memory name, string memory symbol, address _admin, address _recoveryAdmin, uint256 _timelockPeriod, ILosslessController _lossless) internal onlyInitializing {
        __UUPSUpgradeable_init_unchained();
        __AccessControl_init_unchained();        
        __Pausable_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Pausable_init_unchained();
        __ERC20Burnable_init_unchained();
        __ERC20Snapshot_init_unchained();
        __LosslessERC20_init_unchained(_admin, _recoveryAdmin, _timelockPeriod, _lossless);
        __Token_init_unchained();
    }

    function __Token_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSE_MANAGER_ROLE, _msgSender());
        _setupRole(SNAPSHOT_MANAGER_ROLE, _msgSender());
        _setupRole(TXFEE_MANAGER_ROLE, _msgSender());
    	_setRoleAdmin(WHITELISTED_FROM_ROLE, PAUSE_MANAGER_ROLE);
		_setRoleAdmin(WHITELISTED_SENDER_ROLE, PAUSE_MANAGER_ROLE);
		_setRoleAdmin(TXFEE_WHITELISTED_ROLE, TXFEE_MANAGER_ROLE);
    }

    function approve(address spender, uint256 amount) public virtual override(ERC20Upgradeable,LosslessERC20) returns (bool) {
        return LosslessERC20.approve(spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override(ERC20Upgradeable,LosslessERC20) returns (bool) {
        return LosslessERC20.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override(ERC20Upgradeable,LosslessERC20) returns (bool) {
        return LosslessERC20.decreaseAllowance(spender, subtractedValue);
    }

    function transfer(address to, uint256 amount) public virtual override(ERC20Upgradeable,LosslessERC20) returns (bool) {
        return LosslessERC20.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override(ERC20Upgradeable,LosslessERC20) returns (bool) {
        return LosslessERC20.transferFrom(from, to, amount);
    }


    function mint(address account, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function snapshot() external onlyRole(SNAPSHOT_MANAGER_ROLE) {
        _snapshot();
    }

    function currentSnapshotId() external view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function pause() external onlyRole(PAUSE_MANAGER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_MANAGER_ROLE) {
        _unpause();
    }

    function setupTxFee(uint256 _txFee, address _txFeeBeneficiary)  external onlyRole(TXFEE_MANAGER_ROLE) {
        require(_txFee <= 1e18, "bad tx fee");
        txFee = _txFee;
        txFeeBeneficiary = _txFeeBeneficiary;
    }

    function grantRole(bytes32 role, address account) public override(AccessControlUpgradeable) {
        require(!hasRole(BLACKLISTED_ROLE, account), "can not assign role to blacklisted");
        super.grantRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public override(AccessControlUpgradeable) {
        require(role != BLACKLISTED_ROLE, "can not renounce blacklisted role");
        super.renounceRole(role, account);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20PausableUpgradeable, ERC20SnapshotUpgradeable, ERC20Upgradeable) {
        require(!paused() || _checkWhitelist(from, _msgSender()), "transfers are paused");
        require(!_checkBlacklist(_msgSender(), from, to),  "blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        _withdrawTxFee(from, to, amount);
        super._afterTokenTransfer(from, to, amount);        
    }

    function _checkWhitelist(address from, address sender) internal view returns(bool) {
        return hasRole(WHITELISTED_FROM_ROLE, from) || hasRole(WHITELISTED_SENDER_ROLE, sender);
    }

    function _checkBlacklist(address sender, address from, address to) internal view returns(bool) {
        return (
            hasRole(BLACKLISTED_ROLE, from) || 
            hasRole(BLACKLISTED_ROLE, sender) ||
            hasRole(BLACKLISTED_ROLE, to)
        );
    }

    function _withdrawTxFee(address from, address to, uint256 amount) internal virtual {
        if( 
            txFee == 0 ||                   // No txFee
            txFeeBeneficiary == to ||       // Send txFee itself
            txFeeBeneficiary == from ||     // Use the fee
            address(0) == from ||           // Mint
            address(0) == to ||             // Burn
            hasRole(TXFEE_WHITELISTED_ROLE, from) // Sender is txfee-whitelisted
        ){
            return;
        }
        uint256 txFeeAmount = amount * txFee / 1e18;
        _transfer(from, txFeeBeneficiary, txFeeAmount);
    }


    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "admin role required");
    }




}