// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.6;

import "./extensions/presets/ERC20CappedPresetUpgradeable.sol";

contract KMCv1 is ERC20CappedPresetUpgradeable {
    bool private _initlialized;
    bool private _restrictionActive;
    uint256 private _tradingStart;
    uint256 private _maxTransferAmount;
    uint256 private constant _delayBetweenTx = 30;
    mapping(address => bool) private _isWhitelisted;
    mapping(address => bool) private _isUnthrottled;
    mapping(address => uint256) private _previousTx;

    event TradingTimeChanged(uint256 tradingTime);
    event RestrictionActiveChanged(bool active);
    event MaxTransferAmountChanged(uint256 maxTransferAmount);
    event MarkedWhitelisted(address indexed account, bool isWhitelisted);
    event MarkedUnthrottled(address indexed account, bool isUnthrottled);

    function __KMCv1_init(
        string memory _name,
        string memory _symbol,
        uint256 _cap
    ) public initializer {
        ERC20CappedPresetUpgradeable.__ERC20CappedPresetUpgradeable_init(_name, _symbol, _cap);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override transactionThrottler(sender, recipient, amount) {
        super._transfer(sender, recipient, amount);
    }

    function initAntibot() external onlyOwner {
        require(!_initlialized, "Protection: Already initialized");
        _initlialized = true;
        _isUnthrottled[owner()] = true;
        _tradingStart = 1639407600;
        _maxTransferAmount = 15_000 * 10**18;
        _restrictionActive = true;

        emit MarkedUnthrottled(owner(), true);
        emit TradingTimeChanged(_tradingStart);
        emit MaxTransferAmountChanged(_maxTransferAmount);
        emit RestrictionActiveChanged(_restrictionActive);
    }

    function setTradingStart(uint256 _time) external onlyOwner {
        require(_tradingStart > block.timestamp, "Protection: To late");
        _tradingStart = _time;
        emit TradingTimeChanged(_tradingStart);
    }

    function setMaxTransferAmount(uint256 _amount) external onlyOwner {
        _maxTransferAmount = _amount;
        emit MaxTransferAmountChanged(_maxTransferAmount);
    }

    function setRestrictionActive(bool _active) external onlyOwner {
        _restrictionActive = _active;
        emit RestrictionActiveChanged(_restrictionActive);
    }

    function unthrottleAccount(address _account, bool _unthrottled) external onlyOwner {
        require(_account != address(0), "Zero address");
        _isUnthrottled[_account] = _unthrottled;
        emit MarkedUnthrottled(_account, _unthrottled);
    }

    function isUnthrottled(address account) external view returns (bool) {
        return _isUnthrottled[account];
    }

    function whitelistAccount(address _account, bool _whitelisted) external onlyOwner {
        require(_account != address(0), "Zero address");
        _isWhitelisted[_account] = _whitelisted;
        emit MarkedWhitelisted(_account, _whitelisted);
    }

    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted[account];
    }

    modifier transactionThrottler(
        address sender,
        address recipient,
        uint256 amount
    ) {
        require(sender != recipient, "sender is recipient");
        if (_restrictionActive && !_isUnthrottled[recipient] && !_isUnthrottled[sender]) {
            require(block.timestamp >= _tradingStart, "Protection: Transfers disabled");

            if (_maxTransferAmount > 0) {
                require(amount <= _maxTransferAmount, "Protection: Limit exceeded");
            }

            if (!_isWhitelisted[recipient]) {
                require(_previousTx[recipient] + _delayBetweenTx <= block.timestamp, "Protection: 30 sec/tx allowed");
                _previousTx[recipient] = block.timestamp;
            }

            if (!_isWhitelisted[sender]) {
                require(_previousTx[sender] + _delayBetweenTx <= block.timestamp, "Protection: 30 sec/tx allowed");
                _previousTx[sender] = block.timestamp;
            }
        }
        _;
    }
}
