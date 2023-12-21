/**
 *Submitted for verification at Etherscan.io on 2021-10-29
*/

/**
 *Submitted for verification at Etherscan.io on 2021-03-10
*/

// Sources flattened with hardhat v2.1.1 https://hardhat.org

// File contracts/erc20/ERC20.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

abstract contract ERC20 {

    uint256 private _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*
   * Internal Functions for ERC20 standard logics
   */

    function _transfer(address from, address to, uint256 amount)
        internal
        returns (bool success)
    {
        _balances[from] = _balances[from] - amount;
        _balances[to] = _balances[to] + amount;
        emit Transfer(from, to, amount);
        success = true;
    }

    function _approve(address owner, address spender, uint256 amount)
        internal
        returns (bool success)
    {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        success = true;
    }

    function _mint(address recipient, uint256 amount)
        internal
        returns (bool success)
    {
        _totalSupply = _totalSupply + amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(address(0), recipient, amount);
        success = true;
    }

    function _burn(address burned, uint256 amount)
        internal
        returns (bool success)
    {
        _balances[burned] = _balances[burned] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(burned, address(0), amount);
        success = true;
    }

    /*
   * public view functions to view common data
   */

    function totalSupply() external view returns (uint256 total) {
        total = _totalSupply;
    }
    function balanceOf(address owner) external view returns (uint256 balance) {
        balance = _balances[owner];
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256 remaining)
    {
        remaining = _allowances[owner][spender];
    }

    /*
   * External view Function Interface to implement on final contract
   */
    function name() virtual external view returns (string memory tokenName);
    function symbol() virtual external view returns (string memory tokenSymbol);
    function decimals() virtual external view returns (uint8 tokenDecimals);

    /*
   * External Function Interface to implement on final contract
   */
    function transfer(address to, uint256 amount)
        virtual
        external
        returns (bool success);
    function transferFrom(address from, address to, uint256 amount)
        virtual
        external
        returns (bool success);
    function approve(address spender, uint256 amount)
        virtual
        external
        returns (bool success);
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(
        address indexed currentOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(
            msg.sender == _owner,
            "Ownable : Function called by unauthorized user."
        );
        _;
    }

    function owner() external view returns (address ownerAddress) {
        ownerAddress = _owner;
    }

    function transferOwnership(address newOwner)
        public
        onlyOwner
        returns (bool success)
    {
        require(newOwner != address(0), "Ownable/transferOwnership : cannot transfer ownership to zero address");
        success = _transferOwnership(newOwner);
    }

    function renounceOwnership() external onlyOwner returns (bool success) {
        success = _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal returns (bool success) {
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
        success = true;
    }
}


abstract contract ERC20Lockable is ERC20, Ownable {
    struct LockInfo {
        uint256 amount;
        uint256 due;
    }

    mapping(address => LockInfo[]) internal _locks;
    mapping(address => bool) public admin;

    event Lock(address indexed from, uint256 amount, uint256 due);
    event Unlock(address indexed from, uint256 amount);

    modifier checkLock(address from, uint256 amount) {
        require(_balances[from] >= totalLocked(from) + amount, "Cannot send more than unlocked amount");
        _;
    }

    modifier onlyAdmin() {
        require(admin[msg.sender] == true, "Function called by admin user.");
        _;
    }
    function setAdmin(address _admin, bool _approved) external onlyOwner {
        admin[_admin] = _approved;
    }

    function totalLocked(address _from) public view returns (uint256) {
        uint256 lockedAmount;
        for (uint256 i = 0; i < _locks[_from].length; i++) {
            if (_locks[_from][i].due >= block.timestamp) {
                lockedAmount += _locks[_from][i].amount;
            }
        }
        return lockedAmount;
    }

    function lockIdx(address _from, uint256 _due) internal view returns (int256) {
    for (uint256 i = 0; i < _locks[_from].length; i++) {
        if (_locks[_from][i].due == _due) {
            return int256(i); // Return the index as a signed integer
        }
    }
    return -1;
}

    function _lock(address from, uint256 amount, uint256 due) internal returns (bool success) {
        require(due > block.timestamp, "Cannot set due to past");
        require(_balances[from] >= totalLocked(from) + amount, "Locked total should be smaller than balance");
        int256 idx = lockIdx(from, due);
        if (idx >= 0) {
            uint256 existingAmount = _locks[from][uint256(idx)].amount;
            _locks[from][uint256(idx)].amount = existingAmount + amount;
        } else {
            _locks[from].push(LockInfo(amount, due));
        }
        emit Lock(from, amount, due);
    return true;
}

    function _unlock(address from, uint256 due) internal returns (bool success) {
        require(totalLocked(from) != 0, "Cannot set due to past");
        for (uint256 i = 0; i < _locks[from].length; i++) {
            if (_locks[from][i].due == due) {
                uint256 unlockedAmount = _locks[from][i].amount;
                emit Unlock(from, unlockedAmount);
                _locks[from][i] = _locks[from][_locks[from].length - 1];
                _locks[from].pop();
                return true;
            }
        }
        return false;
    }

    function unlock(address from, uint256 due) external onlyAdmin returns (bool success) {
        return _unlock(from, due);
    }

    function unlockAll(address from) external onlyAdmin returns (bool success) {
        for (uint256 i = _locks[from].length; i > 0; i--) {
            _unlock(from, _locks[from][i - 1].due);
        }
        return true;
    }

    function transferWithLockUp(address recipient, uint256 amount, uint256 due) external onlyAdmin returns (bool success) {
        require(recipient != address(0), "Cannot send to zero address");
        _transfer(msg.sender, recipient, amount);
        _lock(recipient, amount, due);
        return true;
    }

    function lockInfo(address locked, uint256 index) external view returns (uint256 amount, uint256 due) {
        amount = _locks[locked][index].amount;
        due = _locks[locked][index].due;
    }
}

abstract contract ERC20Burnable is ERC20 {
    event Burn(address indexed burned, uint256 amount);

    function burn(uint256 amount) 
    external
    returns (bool success)
    {
        success = _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
        success = true;
    }

    function burnFrom(address burned, uint256 amount) 
    external
    returns (bool success)
    {
        _burn(burned, amount);
        emit Burn(burned, amount);
        success = _approve(
            burned,
            msg.sender,
            _allowances[burned][msg.sender] - amount
        );
    }
}

contract ZELIX is
    ERC20Lockable,
    ERC20Burnable
{
    string constant private _name = "ZELIX";
    string constant private _symbol = "ZELIX";
    uint8 constant private _decimals = 18;
    uint256 constant private _initial_supply = 10_000_000_000;
    mapping(address => bool) public blacklists;


    constructor() {
        _mint(_owner, _initial_supply * (10**uint256(_decimals)));
        admin[_owner] = true;
    }

    function blacklist(address _address, bool _approved ) external onlyAdmin   {
        blacklists[_address] = _approved;
    }

    function transfer(address to, uint256 amount)
        override
        external
        checkLock(msg.sender, amount)
        returns (bool success)
    {
        require(
            to != address(0),
            "transfer : Should not send to zero address"
        );
        require(!blacklists[to] && !blacklists[msg.sender], "Blacklisted");

        _transfer(msg.sender, to, amount);
        success = true;
    }

    function transferFrom(address from, address to, uint256 amount)
        override
        external
        checkLock(from, amount)
        returns (bool success)
    {
        require(
            to != address(0),
            "transferFrom : Should not send to zero address"
        );
        require(!blacklists[to] && !blacklists[from], "Blacklisted");

        _transfer(from, to, amount);
        _approve(
            from,
            msg.sender,
            _allowances[from][msg.sender] - amount
        );
        success = true;
    }

    function approve(address spender, uint256 amount)
        override
        external
        returns (bool success)
    {
        require(
            spender != address(0),
            "approve : Should not approve zero address"
        );
        _approve(msg.sender, spender, amount);
        success = true;
    }

    function name() override external pure returns (string memory tokenName) {
        tokenName = _name;
    }

    function symbol() override external pure returns (string memory tokenSymbol) {
        tokenSymbol = _symbol;
    }

    function decimals() override external pure returns (uint8 tokenDecimals) {
        tokenDecimals = _decimals;
    }
}