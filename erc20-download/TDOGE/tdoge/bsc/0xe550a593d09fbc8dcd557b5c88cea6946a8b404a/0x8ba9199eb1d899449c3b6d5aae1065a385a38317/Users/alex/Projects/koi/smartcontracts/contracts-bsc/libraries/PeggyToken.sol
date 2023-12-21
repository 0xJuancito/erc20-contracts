// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "./OwnableContract.sol";

contract PeggyToken is ERC20PresetMinterPauserUpgradeable, OwnableContract{
    using SafeMathUpgradeable for uint256;
    event Lock(address indexed account,uint256 amount);
    event UnLock(address indexed account,uint256 amount);
    uint internal constant  _lockMagicNum = 16;
    uint internal constant  _unLockMagicNum = 0;
    /**
     * @dev store a lock map for compiance work whether allow one user to transfer his coins
     *
     */
    mapping (address => uint) private _lockMap;

    // Dev address.
    address public devaddr;
    // INITIALIZATION DATA
    bool public initialized;
    
    /**
     * @dev statistic data total supply which was locked by compliance officer
     */
    uint256 private _totalSupplyLocked;

    string public icon;

    string public meta;
    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner) public virtual initializer {
        require(!initialized, "already initialized");
        __ERC20PresetMinterPauser_init(name, symbol);
        initializeOwnable(owner);
        devaddr = owner;

        initialized = true;
    }

    function changeIcon(string memory value) public onlyOwner{
        icon = value;
    }
    function changeMeta(string memory value) public onlyOwner{
        meta = value;
    }

    function burn(uint value) override public onlyOwner {
        super.burn(value);
    }

    function finishMinting() public view onlyOwner returns (bool) {
        return false;
    }

    function renounceOwnership() override public onlyOwner {
        revert("renouncing ownership is blocked");
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wtf?");
        devaddr = _devaddr;
    }

    function lockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.add(bal);
        _lockMap[account] = _lockMagicNum;
        emit Lock(account,bal);
    }

    function unLockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.sub(bal,"bal>_totalSupplyLocked");
        _lockMap[account] = _unLockMagicNum;
        emit UnLock(account,bal);
    }

    /**
     * @dev check about the compliance lock
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(ERC20PresetMinterPauserUpgradeable) {
        super._beforeTokenTransfer(account, to, amount);
        uint lock = _lockMap[account];
        require(lock<10,"you are not allowed to move coins atm");
        lock = _lockMap[to];
        if (lock>=10){
            _totalSupplyLocked = _totalSupplyLocked.add(amount);
        }
    }

}