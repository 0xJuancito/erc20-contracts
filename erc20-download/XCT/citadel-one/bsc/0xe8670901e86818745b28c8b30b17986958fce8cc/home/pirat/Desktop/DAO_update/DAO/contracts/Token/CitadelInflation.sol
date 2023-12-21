// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "./CitadelToken.sol";

contract CitadelInflation is CitadelToken {

    struct InflationValues {
        uint inflationPct;
        uint stakingPct;
        uint currentSupply;
        uint yearlySupply;
        uint date;
    }

    uint internal startInflationDate;

    bool private _isInitialized;
    uint private _maxSupply;
    uint private _unlockedSupply;
    uint private _savedInflationYear;
    uint private _yearUnlockedBudget;

    InflationValues[] private _inflationHistory;

    event SetInflationStart(uint date);
    event InflationUpdated(uint index);
    event ChangeInflation(uint indexed issueId, uint pct);
    event ChangeVesting(uint indexed issueId, uint pct);

    modifier activeInflation(){
        require(startInflationDate > 0 && startInflationDate <= _timestamp(), "CitadelInflation: coming soon");
        _;
    }

    function getInflationStartDate() external view
    returns (uint) {
        return startInflationDate;
    }

    function getSavedInflationYear() external view
    returns (uint) {
        return _savedInflationYear;
    }

    function getMaxSupply() external view
    returns (uint) {
        return _maxSupply;
    }

    function inflationPoint(uint index) external view
    returns (InflationValues memory) {
        require(index < _inflationHistory.length, "CitadelInflation: unexpected index");
        return _inflationHistory[index];
    }

    function countInflationPoints() external view
    returns (uint) {
        return _inflationHistory.length;
    }

    function startInflation() external onlyOwner {
        require (startInflationDate == 0, "Inflation is already started");
        startInflationDate = _timestamp();
        _savedInflationYear = startInflationDate;
        _inflationHistory[0].date = _savedInflationYear;
        emit SetInflationStart(startInflationDate);
    }

    function startInflationTo(uint date) external onlyOwner {
        require (startInflationDate == 0 || startInflationDate > _timestamp(), "Inflation is already started");
        require (date > _timestamp(), "Starting date must be in the future");
        startInflationDate = date;
        _savedInflationYear = startInflationDate;
        _inflationHistory[0].date = _savedInflationYear;
        emit SetInflationStart(startInflationDate);
    }

    function withdraw(address to, uint amount) external onlyVestingOrDaoContracts {
        _makeInflationSnapshot();
        _transfer(address(1), to, amount);
    }

    function updateSnapshot() external onlyVestingOrDaoContracts {
        _makeInflationSnapshot();
    }

    function updateInflation(uint issueId, uint pct) external onlyDaoContract {
        require(pct >= 200 && pct <= 3000, "Percentage must be between 2% and 30%");
        
        InflationValues memory lastPoint = _inflationHistory[_inflationHistory.length - 1];
        uint spentTime = _timestamp() - lastPoint.date;
        require(spentTime >= 30 days, "You have to wait 30 days after last changing");

        _makeInflationSnapshot();
        _updateInflation(pct);
        emit ChangeInflation(issueId, pct);
    }

    function updateVesting(uint issueId, uint pct) external onlyDaoContract {
        require(pct >= 10 && pct <= 90, "Percentage must be between 10% and 90%");
        
        InflationValues memory lastPoint = _inflationHistory[_inflationHistory.length - 1];
        uint spentTime = _timestamp() - lastPoint.date;
        require(spentTime >= 30 days, "You have to wait 30 days after last changing");

        _makeInflationSnapshot();
        _updateVesting(pct);
        emit ChangeVesting(issueId, pct);
    }

    function _updateInflation(uint pct) internal {
        require(_maxSupply != _unlockedSupply);

        InflationValues memory lastPoint = _inflationHistory[_inflationHistory.length - 1];
        uint spentTime = _timestamp() - lastPoint.date;

        _unlockedSupply += _yearUnlockedBudget * lastPoint.inflationPct * spentTime / 365 days / 10000;

        require(_unlockedSupply < _maxSupply, "Max supply is reached");

        require(pct <= _restInflPct(), "Too high percentage");

        _inflationHistory.push(InflationValues(pct, lastPoint.stakingPct, _unlockedSupply, _yearUnlockedBudget, _timestamp()));
        emit InflationUpdated(_inflationHistory.length - 1);
    }

    function _updateVesting(uint pct) internal {
        require(_maxSupply != _unlockedSupply);

        InflationValues memory lastPoint = _inflationHistory[_inflationHistory.length - 1];
        uint spentTime = _timestamp() - lastPoint.date;

        _unlockedSupply += _yearUnlockedBudget * lastPoint.inflationPct * spentTime / 365 days / 10000;

        require(_unlockedSupply < _maxSupply, "Max supply is reached");

        _inflationHistory.push(InflationValues(lastPoint.inflationPct, pct, _unlockedSupply, _yearUnlockedBudget, _timestamp()));
        emit InflationUpdated(_inflationHistory.length - 1);
    }

    function _makeInflationSnapshot() internal {
        if (_maxSupply <= _unlockedSupply) return;

        uint spentTime = _timestamp() - _savedInflationYear;
        if (spentTime < 365 days) return;

        InflationValues memory lastPoint = _inflationHistory[_inflationHistory.length - 1];

        uint infl = lastPoint.inflationPct;
        for (uint y = 0; y < spentTime / 365 days; y++) {
            _savedInflationYear += 365 days;
            uint updateUnlock = _yearUnlockedBudget * infl * (_savedInflationYear - lastPoint.date) / 365 days / 10000;
            lastPoint.date = _savedInflationYear;
            if (updateUnlock + _unlockedSupply >= _maxSupply || infl < 200) {
                _unlockedSupply = _maxSupply;
                _inflationHistory.push(InflationValues(_restInflPct(), lastPoint.stakingPct, _unlockedSupply, _unlockedSupply, _savedInflationYear));
                emit InflationUpdated(_inflationHistory.length - 1);
                break;
            } else {
                _unlockedSupply += updateUnlock;
                if (infl > 200) {
                    infl -= 50; // -0.5% each year
                    if (infl < 200) infl = 200; // 2% is minimum
                } else if (infl == 200) {
                    uint rest = _restInflPct();
                    if (rest < 200) infl = rest;
                }
                _inflationHistory.push(InflationValues(infl, lastPoint.stakingPct, _unlockedSupply, _unlockedSupply, _savedInflationYear));
                emit InflationUpdated(_inflationHistory.length - 1);
            }

        }
        _yearUnlockedBudget = _unlockedSupply;
    }

    function _initInflation(
        uint otherSum,
        uint totalAmount,
        uint inflationPct,
        uint stakingPct
    ) internal {

        require(!_isInitialized);

        _isInitialized = true;

        _maxSupply = otherSum + totalAmount;
        _unlockedSupply = otherSum;
        _yearUnlockedBudget = otherSum;

        _inflationHistory.push(InflationValues(inflationPct, stakingPct, _unlockedSupply, _yearUnlockedBudget, _timestamp()));
        emit InflationUpdated(_inflationHistory.length - 1);

    }

    function _restInflPct() private view returns (uint) {
        return (_maxSupply - _unlockedSupply) * 10000 / _unlockedSupply;
    }

}
