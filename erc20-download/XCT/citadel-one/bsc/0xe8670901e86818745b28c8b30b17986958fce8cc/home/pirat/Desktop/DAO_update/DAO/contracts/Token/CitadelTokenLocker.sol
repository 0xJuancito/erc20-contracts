// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "./CitadelInflation.sol";

contract CitadelTokenLocker is CitadelInflation {

    struct HistoryItem {
        uint value;
        uint date;
    }

    mapping (address => uint) public lockedCoins;

    bool private _isInitialized;
    address private _lockerAddress;
    HistoryItem[] private _totalLockedSupplyHistory;
    mapping (address => HistoryItem[]) private _lockedCoinsHistory;

    function lockedBalanceOf(address account) external view returns (uint) {
        return lockedCoins[account];
    }

    function lockedSupply() external view returns (uint) {
        return _lockedTotalSupply();
    }

    function totalSupplyHistoryCount() external view
    returns (uint) {
        return _totalLockedSupplyHistory.length;
    }

    function totalSupplyHistory(uint index) external view
    returns (
        uint value,
        uint date
    ) {
        require (index < _totalLockedSupplyHistory.length, "CitadelTokenLocker: unexpected index");
        value = _totalLockedSupplyHistory[index].value;
        date = _totalLockedSupplyHistory[index].date;
    }

    function lockHistoryCount(address addr) external view
    returns (uint) {
        return _lockedCoinsHistory[addr].length;
    }

    function lockHistory(address addr, uint index) external view
    returns (
        uint value,
        uint date
    ) {
        require (index < _lockedCoinsHistory[addr].length, "CitadelTokenLocker: unexpected index");
        value = _lockedCoinsHistory[addr][index].value;
        date = _lockedCoinsHistory[addr][index].date;
    }

    function stake(uint amount) external activeInflation {
        
        _makeInflationSnapshot();

        _transfer(msg.sender, _lockerAddress, amount);
        lockedCoins[msg.sender] = lockedCoins[msg.sender].add(amount);
        // put mark in history
        _totalLockedSupplyHistory.push(HistoryItem(_lockedTotalSupply(), _timestamp()));
        _lockedCoinsHistory[msg.sender].push(HistoryItem(lockedCoins[msg.sender], _timestamp()));
        // ...
        stakeUpdated();

    }

    function unstake(uint amount) external activeInflation {

        require(lockedCoins[msg.sender] >= amount);

        _makeInflationSnapshot();

        _transfer(_lockerAddress, msg.sender, amount);
        lockedCoins[msg.sender] = lockedCoins[msg.sender].sub(amount);
        // put mark in history
        _totalLockedSupplyHistory.push(HistoryItem(_lockedTotalSupply(), _timestamp()));
        _lockedCoinsHistory[msg.sender].push(HistoryItem(lockedCoins[msg.sender], _timestamp()));
        // ...
        stakeUpdated();

    }

    function restake() external activeInflation {

        require(address(_vesting) != address(0), "CitadelTokenLocker: vesting contract undefined");
        
        uint amount = _vesting.claimFor(msg.sender);

        require(amount > 0);

        _makeInflationSnapshot();
        _transfer(address(1), _lockerAddress, amount);
        
        lockedCoins[msg.sender] = lockedCoins[msg.sender].add(amount);
        // put mark in history
        _totalLockedSupplyHistory.push(HistoryItem(_lockedTotalSupply(), _timestamp()));
        _lockedCoinsHistory[msg.sender].push(HistoryItem(lockedCoins[msg.sender], _timestamp()));
        // ...
        stakeUpdated();

    }

    function stakeUpdated() internal virtual {
        if (address(_dao) != address(0)) {
            _dao.updatedStake(msg.sender);
        }
        if (address(_vesting) != address(0)) {
            _vesting.updateSnapshot(msg.sender);
        }
    }

    function _initCitadelTokenLocker(address lockerAddress_) internal {

        require(!_isInitialized);

        _isInitialized = true;
        _lockerAddress = lockerAddress_;

    }

    function _lockedTotalSupply() private view returns (uint) {
        return balanceOf(_lockerAddress);
    }

}
