// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";


contract PlastikToken is ERC20, ERC20Pausable {
    
    address private _owner;
    mapping(address => bool) private _lockers;
    mapping(address => uint256) private _locks;
    
    constructor() ERC20("PLASTIK Token", "PLASTIK") {
        _owner = _msgSender();
        _lockers[_msgSender()] = true;
        _mint(_msgSender(), 1000000000 * (10 ** decimals()));
    }

    modifier onlyOwner {
      require(msg.sender == _owner);
      _;
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }
    
    function decimals() public view virtual override(ERC20) returns (uint8) {
        return 9;
    }
    
    function setLocker(address locker, bool canLock) public virtual onlyOwner {
        _lockers[locker] = canLock;
    }
    
    function getLockupTime(address _address) public view virtual returns (uint256) {
        return _locks[_address];
    }

    function transferWithLockup(address recipient, uint256 amount, uint numMonthsLockup) public virtual returns (bool) {
        require(numMonthsLockup > 0 && numMonthsLockup <= 12, "Lockup cannot be smaller than 0 or greater than 12 months");
        require(_lockers[_msgSender()], "Only lockers can lock");
        uint256 previousBalance = balanceOf(recipient);
        transfer(recipient, amount);
        if(_locks[recipient] == 0 && previousBalance == 0) {
            _locks[recipient] = block.timestamp + (numMonthsLockup * 4 weeks );
        }
        return true;
    }

    function transferFromWithLockup(address sender, address recipient, uint256 amount, uint numMonthsLockup) public virtual returns (bool) {
        require(numMonthsLockup > 0 && numMonthsLockup <= 12, "Lockup cannot be smaller than 0 or greater than 12 months");
        require(_lockers[_msgSender()], "Only lockers can lock");
        uint256 previousBalance = balanceOf(recipient);
        transferFrom(sender, recipient, amount);
        if(_locks[recipient] == 0 && previousBalance == 0) {
            _locks[recipient] = block.timestamp + (numMonthsLockup * 4 weeks );
        }
        return true;
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        require(_owner == from || _locks[from] == 0 || _locks[from] <= block.timestamp, "Wallet is locked");
        super._beforeTokenTransfer(from, to, amount);
    }
}