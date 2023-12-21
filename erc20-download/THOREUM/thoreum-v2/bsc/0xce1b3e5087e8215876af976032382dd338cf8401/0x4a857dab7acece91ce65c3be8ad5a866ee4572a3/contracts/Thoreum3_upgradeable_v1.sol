// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
pragma solidity ^0.8.4;

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

abstract contract AuthUpgradeable is Initializable, UUPSUpgradeable, ContextUpgradeable {
    address owner;
    mapping (address => bool) private authorizations;

    function __AuthUpgradeable_init() internal onlyInitializing {
        __AuthUpgradeable_init_unchained();
    }

    function __AuthUpgradeable_init_unchained() internal onlyInitializing {
        owner = _msgSender();
        authorizations[_msgSender()] = true;
        __UUPSUpgradeable_init();
    }

    modifier onlyOwner() {
        require(isOwner(_msgSender())); _;
    }

    modifier authorized() {
        require(isAuthorized(_msgSender())); _;
    }

    function authorize(address _address) public onlyOwner {
        authorizations[_address] = true;
        emit Authorized(_address);
    }

    function unauthorize(address _address) public onlyOwner {
        authorizations[_address] = false;
        emit Unauthorized(_address);
    }

    function isOwner(address _address) public view returns (bool) {
        return _address == owner;
    }

    function isAuthorized(address _address) public view returns (bool) {
        return authorizations[_address];
    }

    function transferOwnership(address newOwner) public onlyOwner {
        address oldOwner = owner;
        owner = newOwner;
        authorizations[oldOwner] = false;
        authorizations[newOwner] = true;
        emit Unauthorized(oldOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    event OwnershipTransferred(address oldOwner, address newOwner);
    event Authorized(address _address);
    event Unauthorized(address _address);

    uint256[49] private __gap;
}

abstract contract ReentrancyGuardUpgradeable {
    uint256 private constant _NOT_ENTERED = 0;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }
}


interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IDexPair {
    function sync() external;
}


interface IAutoLiquidityTreasury {
    function autoLiquidify(address _sourceToken, address _pairWithToken, address _dexToken, address _dexRouter) external;
}

interface ITreasury {
    function updateRewards() external;
}

contract Thoreum3_upgradeable_v1 is Initializable, UUPSUpgradeable, AuthUpgradeable, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;

    uint256 public MAX_SUPPLY;
    uint256 public MAX_TAX;

    bool private swapping;
    mapping (address => bool) private isExcludedFromFees;
    mapping (address => bool) public automatedMarketMakerPairs;
    mapping (address => bool) public blacklistFrom;
    mapping (address => bool) public blacklistTo;
    address[] private _markerPairs;

    IDEXRouter public dexRouter;
    address public dexPair;

    address private constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public busdToken;
    address public liquidityToken;
    address public dexToken;
    address public marketingWallet;


    address public taxTreasury;
    ITreasury public nukeTreasury;
    ITreasury public busdTreasury;


    bool public isNotMigrating;
    bool public isFeesOnNormalTransfers;
    uint256 public normalTransferFee;
    uint256 public totalSellFees;
    uint256 public liquidityFee;
    uint256 public busdDividendFee;
    uint256 public marketingFee;
    uint256 public treasuryFee;
    uint256 public rewardBuyerFee;
    uint256 public totalBuyFees;

    uint256 public maxSellTransactionAmount;
    uint256 public swapTokensAtAmount;

    /** Nuke Config **/
    mapping (address => uint256) public lpNukeBuildup;
    bool public lpNukeEnabled;
    uint256 public nukePercentPerSell;
    uint256 public nukePercentToBurn;
    uint256 public minNukeAmount;
    uint256 public totalNuked;
    bool public autoNuke;

    /** Reward Biggest Buyer **/
    bool public isRewardBiggestBuyer;
    uint256 public biggestBuyerPeriod;
    uint256 public launchTime;
    uint256 public  totalBiggestBuyerPaid;
    mapping(uint256 => address) public biggestBuyer;
    mapping(uint256 => uint256) public biggestBuyerAmount;
    mapping(uint256 => uint256) public biggestBuyerPaid;

    /** Breaker Config **/
    bool public isBreakerEnable;
    bool public breakerOnSellOnly;
    int public taxBreakerCheck;
    uint256 public breakerPeriod; // 1 hour
    int public breakerPercent; // activate at 2%
    uint256 public breakerBuyFee;  // buy fee 4%
    uint256 public breakerSellFee; // sell fee 25%
    uint public circuitBreakerFlag;
    uint public circuitBreakerTime;
    uint private timeBreakerCheck;

    /** Auto Liquidity **/
    IAutoLiquidityTreasury public autoLiquidityTreasury;
    bool public autoLiquidityCall;
    bool public isTreasuryInBusd;
    uint public version;

    receive() external payable {}
    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __AuthUpgradeable_init();
        __ERC20_init("Thoreumv3 - Thoreum.Capital", "THOREUM");

        MAX_SUPPLY = 18391124917981203580443344;
        MAX_TAX = 5000;
        busdToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        dexToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        isNotMigrating = false;
        isFeesOnNormalTransfers = true;
        normalTransferFee = 1500;
        totalSellFees = 1500;
        liquidityFee = 100;
        busdDividendFee = 175;
        marketingFee = 50;
        treasuryFee = 150;
        rewardBuyerFee = 25;
        totalBuyFees = liquidityFee + busdDividendFee + marketingFee + treasuryFee + rewardBuyerFee;

        maxSellTransactionAmount = 50000 * 10**18;
        swapTokensAtAmount = 1000 * 10 ** 18;

        /** Nuke Config **/
        lpNukeEnabled = true;
        nukePercentPerSell = 2500;
        nukePercentToBurn = 5000;
        minNukeAmount = 1000 * 10**18;
        autoNuke = true;

        /** Reward Biggest Buyer **/
        isRewardBiggestBuyer = true;
        biggestBuyerPeriod = 12 * 3600;
        launchTime = block.timestamp;

        /** Breaker Config **/
        isBreakerEnable = true;
        breakerOnSellOnly = false;
        breakerPeriod = 3600; // 1 hour
        breakerPercent = 50; // activate at 0.5%
        breakerBuyFee = 400;  // buy fee 4%
        breakerSellFee = 3000; // sell fee 30%

        /** Auto Liquidity **/
        autoLiquidityCall = true;
        isTreasuryInBusd = false;
        version = 1;

        IDEXRouter _dexRouter = IDEXRouter(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8); //pcs 3.1% lp fee, biswap 0.53% lp fee

        address _dexPair = IDEXFactory(_dexRouter.factory()).createPair(address(this), dexToken);

        setDexRouter(address(_dexRouter), _dexPair, dexToken);

        excludeFromFees(address(this), true);
        excludeFromFees(owner, true);
        excludeFromFees(deadAddress,true);

        setMarketingWallet(0x8Ad9CB111d886dBAbBbf232c9A1339B13cB168F8);
        setTaxTreasury(0xeA8BDB211241549CD48A23B18c97f71CB3e22fd7);


        setNukeTreasury(0x5013d1A5a6a0D8bc6Beb60B2A8E67E8aecE3cC80);
        setBusdTreasury(0x5013d1A5a6a0D8bc6Beb60B2A8E67E8aecE3cC80);

        setLiquidityParams(0x95Ac29134fB07e73DEc257cC72D800Ddf8AE76E2,autoLiquidityCall,dexToken);
        _mint(deadAddress, 50 * 10**6 * 10**18 - MAX_SUPPLY);
        _mint(taxTreasury, MAX_SUPPLY);
    }

    /***** Token Feature *****/


    function getPeriod() public view returns (uint256) {
    }

    function payBiggestBuyer(uint256 _hour) external authorized {
    }

    function excludeFromFees(address account, bool _status) public onlyOwner {
        isExcludedFromFees[account] = _status;
        emit ExcludeFromFees(account, _status);
    }

    function checkIsExcludedFromFees(address _account) external view returns (bool) {
    }

    function setDexRouter(address _dexRouter, address _dexPair, address _dexToken) public onlyOwner {
        dexRouter = IDEXRouter(_dexRouter);
        dexPair = _dexPair;
        dexToken = _dexToken;

        setAutomatedMarketMakerPair(dexPair, true);

        _approve(address(this), address(dexRouter), 2**256 - 1);

    }

    function setAutomatedMarketMakerPair(address _dexPair, bool _status) public authorized {
        automatedMarketMakerPairs[_dexPair] = _status;

        if(_status){
            _markerPairs.push(_dexPair);
        }else{
            require(_markerPairs.length >= 1, "Required 1 pair");
            require( _dexPair != dexPair, "Cannot remove dexPair");
            for (uint256 i = 0; i < _markerPairs.length; i++) {
                if (_markerPairs[i] == _dexPair) {
                    _markerPairs[i] = _markerPairs[_markerPairs.length - 1];
                    _markerPairs.pop();
                    break;
                }
            }
        }

        emit SetAutomatedMarketMakerPair(_dexPair, _status);
    }

    function setMaxSell(uint256 _amount) external onlyOwner {
        require(_amount >= 100 * 10**18,"Too small");
        maxSellTransactionAmount = _amount;
    }

    function setMarketingWallet(address _newAddress) public onlyOwner {
        excludeFromFees(_newAddress, true);
        marketingWallet = _newAddress;
    }

    function setTaxTreasury(address _newAddress) public onlyOwner {
        excludeFromFees(_newAddress, true);
        taxTreasury = _newAddress;
    }

    function setNukeTreasury(address _newAddress) public onlyOwner {
        excludeFromFees(_newAddress, true);
        nukeTreasury = ITreasury(_newAddress);
    }

    function setBusdTreasury(address _newAddress) public onlyOwner {
        busdTreasury = ITreasury(_newAddress);
    }

    function setSwapTokensAtAmount(uint256 _amount) external onlyOwner {
    }

    function setIsNotMigrating(bool _status) external onlyOwner {
    }

    function setTokenFees(
        uint256 _liquidityFee,
        uint256 _busdDividendFee,
        uint256 _marketingFee,
        uint256 _treasuryFee,
        uint256 _rewardBuyerFee,
        uint256 _totalSellFees
    ) external onlyOwner {
    }

    function setFeesOnNormalTransfers(bool _status, uint256 _normalTransferFee) external onlyOwner {
    }

    function setIsRewardBiggestBuyer(bool _status, uint256 _biggestBuyerPeriod) external onlyOwner {
    }

    /***** Internal Functions *****/
    function _isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function setBotBlacklist(address account, bool _statusFrom, bool _statusTo) public onlyOwner {
        require(_isContract(account), "Only block contract");
        require(account != dexPair, "Not block dexPair");

        blacklistFrom[account] = _statusFrom;
        blacklistTo[account] = _statusTo;

        emit BotBlacklist(account, _statusFrom, _statusTo);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
    }

    function _swapAndLiquify(uint256 contractTokenBalance) private {
    }

    function _swapTokensForBNB(uint256 tokenAmount, address receiver) private {
    }

    function _swapTokensForBusd(uint256 tokenAmount, address receiver) private {
    }

    function _transferBNBToWallet(address payable recipient, uint256 amount) private {
    }

    function _checkAndPayBiggestBuyer(uint256 _currentPeriod) private {
    }

    function _deactivateCircuitBreaker() internal {
    }

    function _activateCircuitBreaker() internal {
    }

    function setFeesOnBreaker(bool _isBreakerEnable, bool _breakerOnSellOnly, uint256 _breakerPeriod, int _breakerPercent,uint256 _breakerBuyFee, uint256 _breakerSellFee) external onlyOwner {
    }

    function _accuTaxSystem(uint amount, bool isBuy) internal {
    }

    function _getPriceChange(uint r1, uint x) internal pure returns (uint) {
    }

    function setLiquidityParams(address _autoLiquidityTreasury, bool _autoLiquidityCall, address _liquidityToken) public onlyOwner  {
        excludeFromFees(_autoLiquidityTreasury,true);
        autoLiquidityTreasury = IAutoLiquidityTreasury(_autoLiquidityTreasury);
        autoLiquidityCall = _autoLiquidityCall;
        liquidityToken = _liquidityToken;
    }

    function retrieveTokens(address _token) external onlyOwner {
    }

    function retrieveBNB() external onlyOwner {
    }

    event CircuitBreakerActivated();
    event PayBiggestBuyer(address indexed account, uint256 indexed period, uint256 amount);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity);
    event SyncLpErrorEvent(address lpPair, string reason);
    event AutoLpErrorEvent(string reason);
    event BotBlacklist(address indexed account, bool isBlockedFrom, bool isBlockedTo);

}