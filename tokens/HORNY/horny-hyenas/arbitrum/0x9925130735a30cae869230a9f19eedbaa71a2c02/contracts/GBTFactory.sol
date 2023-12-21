// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IGumBallFactory {
    function getTreasury() external view returns (address);
}

interface IXGBT {
    function balanceOf(address account) external view returns (uint256);
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external; 
}

contract GBT is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Bonding Curve Variables
    address public immutable BASE_TOKEN;

    uint256 public immutable reserveVirtualBASE;
    uint256 public reserveRealBASE;
    uint256 public reserveGBT;
    
    uint256 public immutable initial_totalSupply;

    // Treasury Variables
    uint256 public treasuryBASE;
    uint256 public treasuryGBT;

    // Addresses
    address public XGBT;
    address public artist;
    address public immutable factory;

    // Allowlist Variables
    mapping(address => bool) public allowlist;
    mapping(address => uint256) public limit;
    uint256 public immutable start;
    uint256 public immutable delay;

    // Borrow Variables
    uint256 public borrowedTotalBASE;
    mapping(address => uint256) public borrowedBASE;

    // Fee
    uint256 public constant PROTOCOL = 25;
    uint256 public constant TREASURY = 200;
    uint256 public constant GUMBAR = 400;
    uint256 public constant ARTIST = 400;
    uint256 public constant DIVISOR = 1000;

    // Events
    event Buy(address indexed user, uint256 amount);
    event Sell(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Skim(address indexed user);
    event AllowListUpdated(address[] accounts, bool flag);
    event XGBTSet(address indexed _XGBT);
    event ChangeArtist(address newArtist);

    constructor(
        string memory _name,
        string memory _symbol,
        address _baseToken,
        uint256 _initialVirtualBASE,
        uint256 _supplyGBT,
        address _artist,
        address _factory,
        uint256 _delay
        ) ERC20(_name, _symbol) {

        BASE_TOKEN = _baseToken;
        artist = _artist;
        factory = _factory;

        reserveVirtualBASE = _initialVirtualBASE;

        reserveRealBASE = 0;
        initial_totalSupply = _supplyGBT;
        reserveGBT = _supplyGBT;

        start = block.timestamp;
        delay = _delay;

        _mint(address(this), _supplyGBT);

    }

    //////////////////
    ///// Public /////
    //////////////////

    /** @dev returns the current price of {GBT} */
    function currentPrice() external view returns (uint256) {
        return ((reserveVirtualBASE + reserveRealBASE) * 1e18) / reserveGBT;
    }

    /** @dev returns the allowance @param user can borrow */
    function borrowCredit(address account) external view returns (uint256) {
        uint256 borrowPowerGBT = IXGBT(XGBT).balanceOf(account);
        if (borrowPowerGBT == 0) {
            return 0;
        }
        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];
        return borrowableBASE;
    }

    function skimReward() external view returns (uint256) {
        return treasuryBASE * 10 / 10000;
    }

    /** @dev returns amount borrowed by @param user */
    function debt(address account) external view returns (uint256) {
        return borrowedBASE[account];
    }

    function baseBal() external view returns (uint256) {
        return IERC20(BASE_TOKEN).balanceOf(address(this));
    }

    function gbtBal() external view returns (uint256) {
        return IERC20(address(this)).balanceOf(address(this));
    }

    function getFactory() external view returns (address) {
        return factory;
    }

    function initSupply() external view returns (uint256) {
        return initial_totalSupply;
    }

    function floorPrice() external view returns (uint256) {
        return (reserveVirtualBASE * 1e18) / totalSupply();
    }

    function mustStayGBT(address account) external view returns (uint256) {
        uint256 accountBorrowedBASE = borrowedBASE[account];
        if (accountBorrowedBASE == 0) {
            return 0;
        }
        uint256 amount = totalSupply() - (reserveVirtualBASE * totalSupply() / (accountBorrowedBASE + reserveVirtualBASE));
        return amount;
    }

    ////////////////////
    ///// External /////
    ////////////////////

    /** @dev Buy function.  User spends {BASE} and receives {GBT}
      * @param _amountBASE is the amount of the {BASE} being spent
      * @param _minGBT is the minimum amount of {GBT} out
      * @param expireTimestamp is the expire time on txn
      *
      * If a delay was set on the proxy deployment and has not elapsed:
      *     1. the user must be whitelisted by the protocol to call the function
      *     2. the whitelisted user cannont buy more than 1 GBT until the delay has elapsed
    */
    function buy(uint256 _amountBASE, uint256 _minGBT, uint256 expireTimestamp) external nonReentrant {
        require(start + delay <= block.timestamp || allowlist[msg.sender], "Market Closed");
        require(expireTimestamp == 0 || expireTimestamp > block.timestamp, "Expired");
        require(_amountBASE > 0, "Amount cannot be zero");

        address account = msg.sender;

        syncReserves();
        uint256 feeAmountBASE = _amountBASE * PROTOCOL / DIVISOR;
        treasuryBASE += (feeAmountBASE);

        uint256 oldReserveBASE = reserveVirtualBASE + reserveRealBASE;
        uint256 newReserveBASE = oldReserveBASE + _amountBASE - feeAmountBASE;

        uint256 oldReserveGBT = reserveGBT;
        uint256 newReserveGBT = oldReserveBASE * oldReserveGBT / newReserveBASE;

        uint256 outGBT = oldReserveGBT - newReserveGBT;

        require(outGBT > _minGBT, "Less than Min");

        if (start + delay >= block.timestamp) {
            require(outGBT <= 10e18 && limit[account] <= 10e18, "Over allowlist limit");
            limit[account] += outGBT;
            require(limit[account] <= 10e18, "Allowlist amount overflow");
        }

        reserveRealBASE = newReserveBASE - reserveVirtualBASE;
        reserveGBT = newReserveGBT;

        IERC20(BASE_TOKEN).safeTransferFrom(account, address(this), _amountBASE);
        IERC20(address(this)).safeTransfer(account, outGBT);

        emit Buy(account, _amountBASE);
    }

    /** @dev Sell function.  User sells their {GBT} token for {BASE}
      * @param _amountGBT is the amount of {GBT} in
      * @param _minETH is the minimum amount of {ETH} out 
      * @param expireTimestamp is the expire time on txn
    */
    function sell(uint256 _amountGBT, uint256 _minETH, uint256 expireTimestamp) external nonReentrant {
        require(expireTimestamp == 0 || expireTimestamp > block.timestamp, "Expired");
        require(_amountGBT > 0, "Amount cannot be zero");

        address account = msg.sender;

        syncReserves();
        uint256 feeAmountGBT = _amountGBT * PROTOCOL / DIVISOR;
        treasuryGBT += feeAmountGBT;

        uint256 oldReserveGBT = reserveGBT;
        uint256 newReserveGBT = reserveGBT + _amountGBT - feeAmountGBT;

        uint256 oldReserveBASE = reserveVirtualBASE + reserveRealBASE;
        uint256 newReserveBASE = oldReserveBASE * oldReserveGBT / newReserveGBT;

        uint256 outBASE = oldReserveBASE - newReserveBASE;

        require(outBASE > _minETH, "Less than Min");

        reserveRealBASE = newReserveBASE - reserveVirtualBASE;
        reserveGBT = newReserveGBT;

        IERC20(address(this)).safeTransferFrom(account, address(this), _amountGBT);
        IERC20(BASE_TOKEN).safeTransfer(account, outBASE);

        emit Sell(account, _amountGBT);
    }

    /** @dev Distributes fees according to their weights.  Rewards the caller 0.1% of {treasuryBASE} */
    function treasurySkim() external {
        uint256 _treasuryGBT = treasuryGBT;
        uint256 _treasuryBASE = treasuryBASE;

        // Reward for the caller
        uint256 reward = _treasuryBASE * 10 / 10000;   // 0.1%
        _treasuryBASE -= reward;

        treasuryBASE = 0;
        treasuryGBT = 0;

        address treasury = IGumBallFactory(factory).getTreasury();

        IERC20(address(this)).safeApprove(XGBT, 0);
        IERC20(address(this)).safeApprove(XGBT, _treasuryGBT * GUMBAR / DIVISOR);
        IXGBT(XGBT).notifyRewardAmount(address(this), _treasuryGBT * GUMBAR / DIVISOR);
        IERC20(address(this)).safeTransfer(artist, _treasuryGBT * ARTIST / DIVISOR);
        IERC20(address(this)).safeTransfer(treasury, _treasuryGBT * TREASURY / DIVISOR);

        // requires here
        IERC20(BASE_TOKEN).safeApprove(XGBT, 0);
        IERC20(BASE_TOKEN).safeApprove(XGBT, _treasuryBASE * GUMBAR / DIVISOR);
        IXGBT(XGBT).notifyRewardAmount(BASE_TOKEN, _treasuryBASE * GUMBAR / DIVISOR);
        IERC20(BASE_TOKEN).safeTransfer(artist, _treasuryBASE * ARTIST / DIVISOR);
        IERC20(BASE_TOKEN).safeTransfer(treasury, _treasuryBASE * TREASURY / DIVISOR);
        IERC20(BASE_TOKEN).safeTransfer(msg.sender, reward);

        emit Skim(msg.sender);
    }

    /** @dev User borrows an amount of {BASE} equal to @param _amount */
    function borrowSome(uint256 _amount) external nonReentrant {
        require(_amount > 0, "!Zero");

        address account = msg.sender;

        uint256 borrowPowerGBT = IXGBT(XGBT).balanceOf(account);

        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];

        require(borrowableBASE >= _amount, "Borrow Underflow");

        borrowedBASE[account] += _amount;
        borrowedTotalBASE += _amount;

        IERC20(BASE_TOKEN).safeTransfer(account, _amount);

        emit Borrow(account, _amount);
    }

    /** @dev User borrows the maximum amount of {BASE} their locked {XGBT} will allow */
    function borrowMax() external nonReentrant {

        address account = msg.sender;

        uint256 borrowPowerGBT = IXGBT(XGBT).balanceOf(account);

        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];

        borrowedBASE[account] += borrowableBASE;
        borrowedTotalBASE += borrowableBASE;

        IERC20(BASE_TOKEN).safeTransfer(account, borrowableBASE);

        emit Borrow(account, borrowableBASE);
    }

    /** @dev User repays a portion of their debt equal to @param _amount */
    function repaySome(uint256 _amount) external nonReentrant {
        require(_amount > 0, "!Zero");

        address account = msg.sender;
        
        borrowedBASE[account] -= _amount;
        borrowedTotalBASE -= _amount;

        IERC20(BASE_TOKEN).safeTransferFrom(account, address(this), _amount);

        emit Repay(account, _amount);
    }

    /** @dev User repays their debt and opens unlocking of {XGBT} */
    function repayMax() external nonReentrant {

        address account = msg.sender;

        uint256 amountRepayBASE = borrowedBASE[account];
        borrowedBASE[account] = 0;
        borrowedTotalBASE -= amountRepayBASE;

        IERC20(BASE_TOKEN).safeTransferFrom(account, address(this), amountRepayBASE);

        emit Repay(account, amountRepayBASE);
    }

    ////////////////////
    ///// Internal /////
    ////////////////////

    /** @dev Remove yield and rebalance */
    function syncReserves() internal {
        uint256 baseBalance = IERC20(BASE_TOKEN).balanceOf(address(this)) + borrowedTotalBASE;
        if(baseBalance > reserveRealBASE + treasuryBASE) {
            treasuryBASE += (baseBalance - reserveRealBASE - treasuryBASE);
        }
        uint256 gbtBalance = IERC20(address(this)).balanceOf(address(this));
        if (gbtBalance > reserveGBT + treasuryGBT) {
            treasuryGBT += (gbtBalance - reserveGBT - treasuryGBT);
        }
    }

    ////////////////////
    //// Restricted ////
    ////////////////////

    function updateAllowlist(address[] memory accounts, bool _bool) external {
        require(msg.sender == factory || msg.sender == artist, "!AUTH");
        for (uint256 i = 0; i < accounts.length; i++) {
            allowlist[accounts[i]] = _bool;
        }
        emit AllowListUpdated(accounts, _bool);
    }

    function setXGBT(address _XGBT) external OnlyFactory {
        XGBT = _XGBT;
        emit XGBTSet(_XGBT);
    }

    function setArtist(address _artist) external {
        require(msg.sender == artist, "!AUTH");
        artist = _artist;
        emit ChangeArtist(_artist);
    }

    modifier OnlyFactory() {
        require(msg.sender == factory, "!AUTH");
        _;
    }
}

contract GBTFactory {
    address public factory;
    address public lastGBT;

    event FactorySet(address indexed _factory);

    constructor() {
        factory = msg.sender;
    }

    function setFactory(address _factory) external OnlyFactory {
        factory = _factory;
        emit FactorySet(_factory);
    }

    function createGBT(
        string memory _name,
        string memory _symbol,
        address _baseToken,
        uint256 _initialVirtualBASE,
        uint256 _supplyGBT,
        address _artist,
        address _factory,
        uint256 _delay
    ) external OnlyFactory returns (address) {
        GBT newGBT = new GBT(_name, _symbol, _baseToken, _initialVirtualBASE, _supplyGBT, _artist, _factory, _delay);
        lastGBT = address(newGBT);
        return lastGBT;
    }

    modifier OnlyFactory() {
        require(msg.sender == factory, "!AUTH");
        _;
    }
}