// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IBTCMT.sol";

contract BTCMT is ERC20Burnable, AccessControl, IBTCMT {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private constant _ROUND_LEN = 604800;
    uint256 private constant _NUMBER_OF_ROUNDS = 500;

    mapping (address => mapping (address => uint256)) public lockedAllowances;
    mapping (address => uint256) public index;
    mapping (address => TimeAndAmount[]) public allMints;

    uint256 private _lockedTotalSupply;
    mapping (address => uint256) private _lockedAmounts;
    mapping (address => bool) private _farms;

    struct TimeAndAmount {
        uint256 time;
        uint256 total;
        uint256 alreadyUnlocked;
        uint256 transferredAsLocked;
    }
 
    constructor() ERC20("Minto Bitcoin Hashrate Token", "BTCMT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function balanceOfSum (address account) external override view returns (uint256) {
        return super.balanceOf(account) + _lockedAmounts[account];
    }

    function balanceOfLocked (address account) external view returns (uint256) {
        return _lockedAmounts[account] - _vision(account);
    }

    function allMintsLength (address account) external view returns (uint256) {
        return allMints[account].length;
    }

    function addFarm (address farm) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(farm != address(0), "Cannot set zero address as farm");
        _farms[farm] = true;
        emit FarmStatusChanged(farm, true);
    }

    function removeFarm (address farm) onlyRole(DEFAULT_ADMIN_ROLE) external {
        _farms[farm] = false;
        emit FarmStatusChanged(farm, false);
    }

    function mintLocked (address to, uint256 amount, uint256 timeInWeeks) onlyRole(MINTER_ROLE) external {
        require(to != address(0), "Cannot mint to zero address");
        require(timeInWeeks <= _NUMBER_OF_ROUNDS, "Cannot set this time to unlock");
        if (timeInWeeks == 0) {
            _mint(to, amount);
        }
        else {
            _lockedTotalSupply += amount;
            _lockedAmounts[to] += amount;
            uint256 totalToMint = (amount * _NUMBER_OF_ROUNDS) / timeInWeeks;
            allMints[to].push (TimeAndAmount(block.timestamp, totalToMint, 0, totalToMint - amount));
            emit TransferLocked(address(0), to, amount);
        }
    }

    function burnLocked (uint256 amount) external {
        _burnLocked(_msgSender(), amount);
    }

    function burnFromLocked (address from, uint256 amount) external {
        require(lockedAllowances[from][_msgSender()] >= amount, "Not enough locked token allowance");
        _approveLocked(from, _msgSender(), lockedAllowances[from][_msgSender()] - amount);
        _burnLocked(from, amount);
    }

    function approveLocked (address to, uint256 amount) external {
        _approveLocked(_msgSender(), to, amount);
    }

    function increaseLockedAllowance (address to, uint256 amount) external {
        _approveLocked(_msgSender(), to, lockedAllowances[_msgSender()][to] + amount);
    }

    function decreaseLockedAllowance (address to, uint256 amount) external {
        require(lockedAllowances[_msgSender()][to] >= amount, "Allowance would be below zero");
        _approveLocked(_msgSender(), to, lockedAllowances[_msgSender()][to] - amount);
    }

    function transferLocked (address to, uint256 amount) external {
        require(!(_farms[to]), "Cannot transfer to farm");
        _transferLocked(_msgSender(), to, amount);
    }

    function transferFromLocked (address from, address to, uint256 amount) external {
        require(!(_farms[to]), "Cannot transfer to farm");
        require(lockedAllowances[from][_msgSender()] >= amount, "Not enough locked token allowance");
        _approveLocked(from, _msgSender(), lockedAllowances[from][_msgSender()] - amount);
        _transferLocked(from, to, amount);
    }

    function transferFarm (address to, uint256 amountLocked, uint256 amountUnlocked, uint256[] calldata farmIndexes) external override returns (uint256[] memory) {
        address from = _msgSender();
        require(_farms[from], "Sender is not a farm");
        _transfer(from, to, amountUnlocked);
        uint256[] memory newIndexes = _transferLockedForFarm(from, to, amountLocked, farmIndexes);
        if (_lockedAmounts[to] > 0) {
            unlock(to, 0);
        }
        return newIndexes;
    }

    function transferFromFarm (address from, uint256 amountLocked, uint256 amountUnlocked) external override returns (uint256[] memory) {
        address to = _msgSender();
        require(_farms[to], "Sender is not a farm");
        require(lockedAllowances[from][to] >= amountLocked, "Not enough locked token allowance");
        _approveLocked(from, to, lockedAllowances[from][to] - amountLocked);
        uint256 len = allMints[to].length;
        _transferLocked(from, to, amountLocked);
        uint256[] memory m = new uint256[](allMints[to].length - len);
        for (uint256 i = len; i < allMints[to].length; i++) {
            m[i - len] = i;
        }
        transferFrom(from, to, amountUnlocked);
        return (m);
    }

    function totalSupply() public view override(ERC20,IERC20) returns (uint256) {
        return super.totalSupply() + _lockedTotalSupply;
    }

    function balanceOf (address account) public view override(ERC20,IERC20) returns (uint256) {
        return super.balanceOf(account) + _vision(account);
    }

    function unlock (address who, uint256 numberOfBlocks) public {
        require(!(_farms[who]), "Cannot unlock farm");
        require(_lockedAmounts[who] > 0, "No tokens locked");
        uint256 l = allMints[who].length;
        uint256 i = index[who];
        require(i + numberOfBlocks <= l, "Cannot unlock this many blocks, exceeds length");
        uint256 toUnlockTotal = 0;
        if (numberOfBlocks == 0 ) {
            numberOfBlocks = l;
        }
        else {
            numberOfBlocks += i;
        }
        for (i; i < numberOfBlocks; i++) {
            uint256 _total = allMints[who][i].total;
            uint256 _alreadyUnlocked = allMints[who][i].alreadyUnlocked;
            uint256 _transferredAsLocked = allMints[who][i].transferredAsLocked;
            if ( (_alreadyUnlocked + _transferredAsLocked >= _total) && index[who] == i) {
                index[who] = i+1;
                delete allMints[who][i];
            }
            else {
                uint256 rounds = ((block.timestamp - allMints[who][i].time) / _ROUND_LEN);
                if(rounds > 0) {
                    uint256 toUnlock = _total * rounds / _NUMBER_OF_ROUNDS;
                    if (_alreadyUnlocked < toUnlock) {
                        toUnlock = toUnlock - _alreadyUnlocked;
                    }
                    else {
                        toUnlock = 0;
                    }
                    if (toUnlock > 0) {
                        uint256 allowed = _total - (_transferredAsLocked + _alreadyUnlocked);
                        if (allowed > 0) {
                            if (toUnlock > allowed){
                                toUnlock = allowed;
                            }
                            allMints[who][i].alreadyUnlocked = _alreadyUnlocked + toUnlock;
                            toUnlockTotal += toUnlock;
                            if ( (allMints[who][i].alreadyUnlocked + _transferredAsLocked >= _total) && index[who] == i){
                                index[who] = i+1;
                                delete allMints[who][i];
                            }
                        }
                    }
                }
            }
        }
        _lockedAmounts[who] -= toUnlockTotal;
        _lockedTotalSupply -= toUnlockTotal;
        emit TransferLocked(who, address(0), toUnlockTotal);
        _mint(who, toUnlockTotal);
    }

    function _beforeTokenTransfer (address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0) && !(_farms[from]) && !(_farms[to]) && super.balanceOf(from) < amount && _lockedAmounts[from] > 0) {
            unlock(from, 0);
        }
    }

    function _vision (address who) private view returns (uint256) {
        uint256 toUnlockTotal = 0;
        for (uint256 i = index[who]; i < allMints[who].length; i++) {
            uint256 _total = allMints[who][i].total;
            uint256 _alreadyUnlocked = allMints[who][i].alreadyUnlocked;
            uint256 _transferredAsLocked = allMints[who][i].transferredAsLocked;
            uint256 rounds = ((block.timestamp - allMints[who][i].time) / _ROUND_LEN);
            if(rounds > 0) {
                uint256 toUnlock = _total * rounds / _NUMBER_OF_ROUNDS;
                if (_alreadyUnlocked < toUnlock) {
                    toUnlock = toUnlock - _alreadyUnlocked;
                }
                else {
                    toUnlock = 0;
                }
                if (toUnlock > 0) {
                    uint256 allowed = _total - (_transferredAsLocked + _alreadyUnlocked);
                    if (allowed > 0) {
                        if (toUnlock > allowed){
                            toUnlock = allowed;
                        }
                        toUnlockTotal += toUnlock;
                    }
                }
            }
        }
        return toUnlockTotal;
    }

    function _burnLocked (address from, uint256 amount) private {
        require(from != address(0), "Cannot burn from zero address");
        unlock(from, 0);
        require(_lockedAmounts[from] >= amount, "Not enough locked token to burn");
        _burnLoop(from, address(0), amount);
    }

    function _approveLocked (address from, address to, uint256 amount) private {
        require(from != address(0), "Cannot approve from zero address");
        require(to != address(0), "Cannot approve to zero address");
        lockedAllowances[from][to] = amount;
        emit ApprovalLocked(from, to, amount);
    }

    function _transferLocked (address from, address to, uint256 amount) private {
        uint256[] memory indexes = new uint256[](0);
        _transferLockedForFarm(from, to, amount, indexes);
    }

    function _transferLockedForFarm (address from, address to, uint256 amount, uint256[] memory indexes) private returns (uint256[] memory newIndexes) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        if (!(_farms[from]) && _lockedAmounts[from] > 0){
            unlock(from, 0);
        }
        require(_lockedAmounts[from] >= amount, "Not enough locked token to transfer");
        if (_farms[from]) {
            newIndexes = _burnLoopForFarm(from, to, amount, indexes);
            return newIndexes;
        }
        else {
            _burnLoop(from, to, amount);
        }
    }

    function _burnLoop (address from, address to, uint256 amount) private {
        uint256[] memory indexes = new uint256[](0);
        _burnLoopForFarm(from, to, amount, indexes);
    }

    function _burnLoopForFarm (address from, address to, uint256 amount, uint256[] memory indexes) private returns (uint256[] memory newIndexes){
        _lockedAmounts[from] -= amount;
        if (to == address(0)) {
            _lockedTotalSupply -= amount;
        }
        else {
            _lockedAmounts[to] += amount;
        }
        emit TransferLocked(from, to, amount);
        bool farmWithdrawal = false;
        uint256 i;
        if (_farms[from]) {
            farmWithdrawal = true;
        }
        if (farmWithdrawal) {
            i = indexes.length;
        }
        else {
            i = allMints[from].length;
        }
        for (i; i > 0; i--) {
            if (amount > 0) {
                uint256 _time;
                uint256 _total;
                uint256 _alreadyUnlocked;
                uint256 _transferredAsLocked;
                uint256 avaliable;
                if (farmWithdrawal) {
                    _time = allMints[from][indexes[i-1]].time;
                    _total = allMints[from][indexes[i-1]].total;
                    _alreadyUnlocked = allMints[from][indexes[i-1]].alreadyUnlocked;
                    _transferredAsLocked = allMints[from][indexes[i-1]].transferredAsLocked;
                    avaliable = _total - (_alreadyUnlocked + _transferredAsLocked);
                }
                else {
                    _time = allMints[from][i-1].time;
                    _total = allMints[from][i-1].total;
                    _alreadyUnlocked = allMints[from][i-1].alreadyUnlocked;
                    _transferredAsLocked = allMints[from][i-1].transferredAsLocked;
                    avaliable = _total - (_alreadyUnlocked + _transferredAsLocked);
                }
                if (avaliable > 0) {
                    uint256 toTransfer;
                    if (avaliable > amount) {
                        toTransfer = amount;
                    }
                    else {
                        toTransfer = avaliable;
                    }
                    amount -= toTransfer;
                    if (to != address(0)) {
                        allMints[to].push (TimeAndAmount (_time, _total, _alreadyUnlocked + (avaliable - toTransfer), _transferredAsLocked));
                    }
                    if (farmWithdrawal) {
                        allMints[from][indexes[i-1]].transferredAsLocked = _transferredAsLocked + toTransfer;
                    }
                    else {
                        allMints[from][i-1].transferredAsLocked = _transferredAsLocked + toTransfer;
                    }
                }
            }
        }
        if (farmWithdrawal) {
            uint256 l = indexes.length;
            newIndexes = new uint256[](l);
            if (l > 0) {
                uint256 indexu = 0;
                for (i=0; i < l; i++) {
                    if ((allMints[from][indexes[i]].alreadyUnlocked + allMints[from][indexes[i]].transferredAsLocked) >= allMints[from][indexes[i]].total) {
                        delete allMints[from][indexes[i]];
                    }
                    else {
                        newIndexes[indexu]=indexes[i];
                        indexu++;
                    }
                }
                uint256 toReduce = l - indexu;
                assembly { mstore(newIndexes, sub(mload(newIndexes), toReduce)) }
            }
            return newIndexes;
        }
    }
}