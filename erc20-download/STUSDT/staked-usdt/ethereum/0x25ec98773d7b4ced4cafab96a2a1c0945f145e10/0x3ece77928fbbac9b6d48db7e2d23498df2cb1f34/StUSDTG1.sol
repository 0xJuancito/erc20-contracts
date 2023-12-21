// File contracts/interface/IERC20.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {

    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Transfer(address indexed from, address indexed to, uint256 value);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() external pure returns (uint8);

    /**
     * @return the name of the token.
     */
    function name() external pure returns (string memory);

    /**
     * @return the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external pure returns (string memory);

}


// File contracts/interface/IStUSDT.sol

pragma solidity ^0.8.18;

interface IStUSDT is IERC20 {

    function sharesOf(address _account) external view returns (uint256);

    function getSharesByUnderlying(uint256 _underlyingAmount) external view returns (uint256);

    function getUnderlyingByShares(uint256 _sharesAmount) external view returns (uint256);

    function mint(address _owner, uint256 _amountOfStUSDT) external returns (uint256);

    function burnShares(address _owner, uint256 _amountOfShares) external returns (uint256);

}


// File contracts/AdminStorage.sol

pragma solidity ^0.8.18;

contract AdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of this contract
    */
    address public implementation;

    /**
    * @notice Pending brains of this contract
    */
    address public pendingImplementation;
}


// File contracts/interface/IBlackListManager.sol

pragma solidity 0.8.18;

interface IBlackListManager {

    function isBlackListed(address _address) external view returns (bool);
}


// File contracts/StUSDTStorage.sol

pragma solidity ^0.8.18;


contract StUSDTStorage is AdminStorage {

    uint256 public constant SCALE = 1e18;

    // -------------------------------- storages --------------------------------

    mapping(address => uint256) internal shares;

    mapping(address => mapping(address => uint256)) internal allowances;

    uint256 public totalShares;

    uint256 public totalUnderlying;

    mapping(address => bool) public minters;

    mapping(address => bool) public burners;

    uint256 public maxTotalUnderlying;

    uint256 public increaseRateLimit;

    uint256 public decreaseRateLimit;

    uint256 public lastRebaseTime;

    uint256 public rebaseIntervalTime;

    address public rebaseAdmin;

    address public mintPausedAdmin;

    bool public mintPaused;

    IBlackListManager public blackListManager;

}


// File contracts/StUSDTG1.sol

pragma solidity ^0.8.18;


contract StUSDTG1 is StUSDTStorage, IStUSDT {

    // -------------------------------- events --------------------------------
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    event IncreaseBase(uint256 oldTotalUnderlying, uint256 newTotalUnderlying, uint256 totalShares);
    event DecreaseBase(uint256 oldTotalUnderlying, uint256 newTotalUnderlying, uint256 totalShares);

    event MintStateUpdated(bool state);

    event Mint(
        address indexed minter,
        address indexed owner,
        uint256 amountOfShares,
        uint256 amountOfStUSDT,
        uint256 userRemainingShares,
        uint256 totalShares,
        uint256 totalUnderlying
    );

    event SharesBurnt(
        address indexed burner,
        address indexed owner,
        uint256 amountOfShares,
        uint256 amountOfStUSDT,
        uint256 userRemainingShares,
        uint256 totalShares,
        uint256 totalUnderlying
    );

    event MaxTotalUnderlyingUpdated(uint256 oldMaxTotal, uint256 newMaxTotal);

    event RebaseAdminUpdated(address oldRebaseAdmin, address newRebaseAdmin);

    event RebaseIntervalTimeUpdated(uint256 oldIntervalTime, uint256 newIntervalTime);

    event IncreaseRateLimitUpdated(uint256 oldRateLimit, uint256 newRateLimit);

    event DecreaseRateLimitUpdated(uint256 oldRateLimit, uint256 newRateLimit);

    event MintPausedAdminUpdated(address oldMintPausedAdmin, address newMintPausedAdmin);

    event MintersAdded(address[] mintersAdded);

    event MintersRemoved(address[] mintersRemoved);

    event BurnersAdded(address[] burnersAdded);

    event BurnersRemoved(address[] burnersRemoved);

    event BlackListManagerUpdated(address oldAddr, address newAddr);

    // -------------------------------- modifiers --------------------------------
    modifier onlyAdmin() {
        require(msg.sender == admin, "NOT_ADMIN");
        _;
    }

    modifier onlyRebaseAdmin() {
        require(msg.sender == rebaseAdmin, "NOT_REBASE_ADMIN");
        _;
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "NOT_MINTER");
        _;
    }

    modifier onlyBurner() {
        require(isBurner(msg.sender), "NOT_BURNER");
        _;
    }

    modifier notOnBlackList(address _address) {
        if (address(blackListManager) != address(0)) {
            require(!blackListManager.isBlackListed(_address), "ADDRESS_IS_BLACKLISTED");
        }
        _;
    }

    modifier onlyMintPausedAdmin() {
        require(msg.sender == mintPausedAdmin, "NOT_MINT_PAUSED_ADMIN");
        _;
    }

    // -------------------------------- trc20 functions --------------------------------
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function name() external pure returns (string memory) {
        return "Staked USDT";
    }

    function symbol() external pure returns (string memory) {
        return "stUSDT";
    }

    function totalSupply() public view returns (uint256) {
        return totalUnderlying;
    }

    function balanceOf(address _account) public view returns (uint256) {
        return getUnderlyingByShares(shares[_account]);
    }

    function transfer(address _recipient, uint256 _amount)
        public
        notOnBlackList(msg.sender)
        returns (bool)
    {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount)
        public
        returns (bool)
    {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount)
        public
        notOnBlackList(msg.sender)
        notOnBlackList(_sender)
        returns (bool)
    {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance > 0, "ZERO_ALLOWANCE");
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "DECREASED_ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }

    // -------------------------------- base functions --------------------------------

    /**
     * @return the amount of shares owned by `_account`.
     */
    function sharesOf(address _account) public view returns (uint256) {
        return shares[_account];
    }

    function getSharesByUnderlying(uint256 _underlyingAmount) public view returns (uint256) {
        uint256 _totalUnderlying = totalUnderlying;
        uint256 _totalShares = totalShares;
        if (_totalUnderlying == 0 && _totalShares == 0) {
            // assume that shares correspond to underlying 1-to-1
            return _underlyingAmount;
        } else {
            return _underlyingAmount * _totalShares / _totalUnderlying;
        }
    }

    function getUnderlyingByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 _totalUnderlying = totalUnderlying;
        uint256 _totalShares = totalShares;
        if (_totalUnderlying == 0 && _totalShares == 0) {
            return 0;
        } else {
            return _sharesAmount * _totalUnderlying / _totalShares;
        }
    }

    function transferShares(address _recipient, uint256 _sharesAmount)
        public
        notOnBlackList(msg.sender)
        returns (uint256)
    {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getUnderlyingByShares(_sharesAmount);

        emit Transfer(msg.sender, _recipient, tokensAmount);
        emit TransferShares(msg.sender, _recipient, _sharesAmount);
        return tokensAmount;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = getSharesByUnderlying(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        emit Transfer(_sender, _recipient, _amount);
        emit TransferShares(_sender, _recipient, _sharesToTransfer);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

        uint256 currentSenderShares = shares[_sender];
        require(_sharesAmount <= currentSenderShares, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] = currentSenderShares - _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    // -------------------------------- feature functions --------------------------------
    function isMinter(address _address) public view returns (bool) {
        return minters[_address];
    }

    function isBurner(address _address) public view returns (bool) {
        return burners[_address];
    }

    function mint(
        address _owner,
        uint256 _amountOfStUSDT
    )
        external
        onlyMinter
        notOnBlackList(_owner)
        returns (uint256)
    {
        require(!mintPaused, "MINT_IS_PAUSED");

        uint256 amountOfShares = getSharesByUnderlying(_amountOfStUSDT);
        require(amountOfShares > 0, "ZERO_SHARE_TO_MINT");

        uint256 remainingTotalUnderlying = totalUnderlying + _amountOfStUSDT;
        require(remainingTotalUnderlying <= maxTotalUnderlying, "EXCEED_MAX_TOTAL_UNDERLYING");
        totalUnderlying = remainingTotalUnderlying;

        uint256 remainingTotalShares = totalShares + amountOfShares;
        totalShares = remainingTotalShares;

        uint256 userShares = shares[_owner];
        userShares += amountOfShares;
        shares[_owner] = userShares;

        emit Mint(msg.sender, _owner, amountOfShares, _amountOfStUSDT,
            userShares, remainingTotalShares, remainingTotalUnderlying);

        emit Transfer(address(0), _owner, _amountOfStUSDT);
        emit TransferShares(address(0), _owner, amountOfShares);
        return amountOfShares;
    }

    function burnShares(
        address _owner,
        uint256 _amountOfShares
    )
        external
        onlyBurner
        returns (uint256)
    {
        require(_amountOfShares > 0, "ZERO_SHARE_TO_BURN");
        require(_amountOfShares <= shares[_owner], "NO_ENOUGH_BALANCE");

        uint256 amountOfStUSDT = getUnderlyingByShares(_amountOfShares);
        uint256 currentAllowance = allowances[_owner][msg.sender];
        require(currentAllowance >= amountOfStUSDT, "AMOUNT_EXCEEDS_ALLOWANCE");

        uint256 remainingTotalShares = totalShares - _amountOfShares;
        uint256 userShares = shares[_owner] - _amountOfShares;
        uint256 remainingTotalUnderlying = totalUnderlying - amountOfStUSDT;

        totalShares = remainingTotalShares;
        shares[_owner] = userShares;
        totalUnderlying = remainingTotalUnderlying;

        _approve(_owner, msg.sender, currentAllowance - amountOfStUSDT);

        emit SharesBurnt(msg.sender, _owner, _amountOfShares, amountOfStUSDT,
            userShares, remainingTotalShares, remainingTotalUnderlying);

        emit Transfer(_owner, address(0), amountOfStUSDT);
        emit TransferShares(_owner, address(0), _amountOfShares);
        return amountOfStUSDT;
    }

    function increaseBase(uint256 _increaseAmount) external onlyRebaseAdmin {
        require(block.timestamp - lastRebaseTime >= rebaseIntervalTime, "REBASE_TOO_OFTEN");

        uint256 _totalUnderlying = totalUnderlying;
        require(_totalUnderlying > 0 && _totalUnderlying * increaseRateLimit / SCALE >= _increaseAmount,
            "REBASE_AMOUNT_EXCEED_LIMIT");

        uint256 oldTotalUnderlying = _totalUnderlying;
        _totalUnderlying += _increaseAmount;
        totalUnderlying = _totalUnderlying;

        lastRebaseTime = block.timestamp;

        emit IncreaseBase(oldTotalUnderlying, _totalUnderlying, totalShares);
    }

    function decreaseBase(uint256 _decreaseAmount) external onlyRebaseAdmin {
        require(block.timestamp - lastRebaseTime >= rebaseIntervalTime, "REBASE_TOO_OFTEN");

        uint256 _totalUnderlying = totalUnderlying;
        require(_totalUnderlying > 0 && _totalUnderlying * decreaseRateLimit / SCALE >= _decreaseAmount,
            "REBASE_AMOUNT_EXCEED_LIMIT");

        uint256 oldTotalUnderlying = _totalUnderlying;
        _totalUnderlying -= _decreaseAmount;
        totalUnderlying = _totalUnderlying;

        lastRebaseTime = block.timestamp;

        emit DecreaseBase(oldTotalUnderlying, _totalUnderlying, totalShares);
    }

    function setMintPaused(bool _newState) external onlyMintPausedAdmin {
        require(_newState != mintPaused, "MINT_STATE_NOT_CHANGE");
        mintPaused = _newState;
        emit MintStateUpdated(_newState);
    }

    function setRebaseAdmin(address _newRebaseAdmin) external onlyAdmin {
        address oldRebaseAdmin = rebaseAdmin;
        rebaseAdmin = _newRebaseAdmin;
        emit RebaseAdminUpdated(oldRebaseAdmin, _newRebaseAdmin);
    }

    function setRebaseIntervalTime(uint256 _newTimeLimit) external onlyAdmin {
        uint256 oldTimeLimit = rebaseIntervalTime;
        rebaseIntervalTime = _newTimeLimit;
        emit RebaseIntervalTimeUpdated(oldTimeLimit, _newTimeLimit);
    }

    function setIncreaseRateLimit(uint256 _newRateLimit) external onlyAdmin {
        require(_newRateLimit <= SCALE, "INVALID_RATE_LIMIT");
        uint256 oldRateLimit = increaseRateLimit;
        increaseRateLimit = _newRateLimit;
        emit IncreaseRateLimitUpdated(oldRateLimit, _newRateLimit);
    }

    function setDecreaseRateLimit(uint256 _newRateLimit) external onlyAdmin {
        require(_newRateLimit <= SCALE, "INVALID_RATE_LIMIT");
        uint256 oldRateLimit = decreaseRateLimit;
        decreaseRateLimit = _newRateLimit;
        emit DecreaseRateLimitUpdated(oldRateLimit, _newRateLimit);
    }

    function setBlackListManager(address _newBlackListManager) external onlyAdmin {
        address oldAddr = address(blackListManager);
        blackListManager = IBlackListManager(_newBlackListManager);
        emit BlackListManagerUpdated(oldAddr, _newBlackListManager);
    }

    function setMintPausedAdmin(address _newMintPausedAdmin) external onlyAdmin {
        address oldMintPausedAdmin = mintPausedAdmin;
        mintPausedAdmin = _newMintPausedAdmin;
        emit MintPausedAdminUpdated(oldMintPausedAdmin, _newMintPausedAdmin);
    }

    function addMinters(address[] calldata _mintersToAdd) external onlyAdmin {
        for (uint256 i = 0; i < _mintersToAdd.length; ++i) {
            address minter = _mintersToAdd[i];
            minters[minter] = true;
        }
        emit MintersAdded(_mintersToAdd);
    }

    function removeMinters(address[] calldata _mintersToRemove) external onlyAdmin {
        for (uint256 i = 0; i < _mintersToRemove.length; ++i) {
            address minter = _mintersToRemove[i];
            minters[minter] = false;
        }
        emit MintersRemoved(_mintersToRemove);
    }

    function setMaxTotalUnderlying(uint256 _maxTotalUnderlying) external onlyAdmin {
        uint256 oldMaxTotalUnderlying = maxTotalUnderlying;
        maxTotalUnderlying = _maxTotalUnderlying;
        emit MaxTotalUnderlyingUpdated(oldMaxTotalUnderlying, _maxTotalUnderlying);
    }

    function addBurners(address[] calldata _burnersToAdd) external onlyAdmin {
        for (uint256 i = 0; i < _burnersToAdd.length; ++i) {
            address burner = _burnersToAdd[i];
            burners[burner] = true;
        }
        emit BurnersAdded(_burnersToAdd);
    }

    function removeBurners(address[] calldata _burnersToRemove) external onlyAdmin {
        for (uint256 i = 0; i < _burnersToRemove.length; ++i) {
            address burner = _burnersToRemove[i];
            burners[burner] = false;
        }
        emit BurnersRemoved(_burnersToRemove);
    }
}