// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract TransactionThrottler is AccessControl {
    bool private _restrictionActive;
    uint256 private _tradingStart;
    uint256 private _restrictionEndTime;
    uint256 private _maxTransferAmount;
    uint256 private constant _delayBetweenTx = 30;
    mapping(address => bool) private _isWhitelisted;
    mapping(address => uint256) private _previousTx;

    event TradingTimeChanged(uint256 tradingTime);
    event RestrictionEndTimeChanged(uint256 endTime);
    event RestrictionActiveChanged(bool active);
    event MaxTransferAmountChanged(uint256 maxTransferAmount);
    event MarkedWhitelisted(address indexed account, bool isWhitelisted);

    constructor() {
        _tradingStart = block.timestamp + 3 days;
        _restrictionEndTime = _tradingStart + 30 * 60;
        _maxTransferAmount = 60000 * 10**18;
        _restrictionActive = true;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setTradingStart(uint256 _time)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_tradingStart > block.timestamp, "Protection: To late");
        _tradingStart = _time;
        _restrictionEndTime = _time + 30 * 60;
        emit TradingTimeChanged(_tradingStart);
        emit RestrictionEndTimeChanged(_restrictionEndTime);
    }

    function setMaxTransferAmount(uint256 _amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_restrictionEndTime > block.timestamp, "Protection: To late");
        _maxTransferAmount = _amount;
        emit MaxTransferAmountChanged(_maxTransferAmount);
    }

    function setRestrictionActive(bool _active)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _restrictionActive = _active;
        emit RestrictionActiveChanged(_active);
    }

    function whitelistAccount(address _account, bool _whitelisted)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_account != address(0), "Zero address");
        _isWhitelisted[_account] = true;
        emit MarkedWhitelisted(_account, _whitelisted);
    }

    modifier transactionThrottler(
        address sender,
        address recipient,
        uint256 amount
    ) {
        if (_tradingStart > block.timestamp) {
            require(
                hasRole(DEFAULT_ADMIN_ROLE, sender) ||
                    hasRole(DEFAULT_ADMIN_ROLE, recipient),
                "Protection: Transfers disabled"
            );
        } else if (_restrictionActive) {
            uint256 requiredDelay;

            // During the first restricted period tokens amount are limited
            if (_restrictionEndTime > block.timestamp) {
                require(
                    amount <= _maxTransferAmount,
                    "Protection: Limit exceeded"
                );
                requiredDelay = 60 seconds;
            } else {
                requiredDelay = _delayBetweenTx;
            }

            if (!_isWhitelisted[recipient]) {
                require(
                    _previousTx[recipient] + requiredDelay <= block.timestamp,
                    "Protection: 1 tx/min allowed"
                );
                _previousTx[recipient] = block.timestamp;
            }
            if (!_isWhitelisted[sender]) {
                require(
                    _previousTx[sender] + requiredDelay <= block.timestamp,
                    "Protection: 1 tx/min allowed"
                );
                _previousTx[sender] = block.timestamp;
            }
        }
        _;
    }
}
