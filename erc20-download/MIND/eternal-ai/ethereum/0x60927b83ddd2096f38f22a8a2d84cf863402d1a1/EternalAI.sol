/**

ETERNAL AI - Immortality Starts Here.

Website: https://immortalitystartshere.io
Telegram: https://t.me/EternalAI
Linktree: https://linktr.ee/EternalAI

*/

// ██████  ███████ ██    ██  ██████  ██      ██    ██ ███████ ██  ██████  ███    ██                   
// ██   ██ ██      ██    ██ ██    ██ ██      ██    ██     ██  ██ ██    ██ ████   ██                  
// ██████  █████   ██    ██ ██    ██ ██      ██    ██   ██    ██ ██    ██ ██ ██  ██                   
// ██   ██ ██       ██  ██  ██    ██ ██      ██    ██  ██     ██ ██    ██ ██  ██ ██                   
// ██   ██ ███████   ████    ██████  ███████  ██████  ███████ ██  ██████  ██   ████    

// CONTRACT DEVELOPED BY REVOLUZION

// Revoluzion Ecosystem
// WEB: https://revoluzion.io
// DAPP: https://revoluzion.app

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/********************************************************************************************
  INTERFACE
********************************************************************************************/

interface IERC20 {
    
    // EVENT 

    event Transfer(address indexed from, address indexed to, uint256 value);
    
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // FUNCTION

    function name() external view returns (string memory);
    
    function symbol() external view returns (string memory);
    
    function decimals() external view returns (uint8);
    
    function totalSupply() external view returns (uint256);
    
    function balanceOf(address account) external view returns (uint256);
    
    function transfer(address to, uint256 amount) external returns (bool);
    
    function allowance(address owner, address spender) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPair {

    // FUNCTION

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IFactory {

    // FUNCTION

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {

    // FUNCTION

    function WETH() external pure returns (address);
        
    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable;
    
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface ICommonError {

    // ERROR

    error CannotUseCurrentAddress(address current);

    error CannotUseCurrentValue(uint256 current);

    error CannotUseCurrentState(bool current);

    error InvalidAddress(address invalid);

    error InvalidValue(uint256 invalid);
}

/********************************************************************************************
  ACCESS
********************************************************************************************/

abstract contract Ownable {
    
    // DATA

    address private _owner;

    // MODIFIER

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    // ERROR

    error InvalidOwner(address account);

    error UnauthorizedAccount(address account);

    // CONSTRUCTOR

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    // EVENT
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // FUNCTION
    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/********************************************************************************************
  TOKEN
********************************************************************************************/

contract EternalAI is Ownable, ICommonError, IERC20 {

    // DATA

    IRouter public router;

    string private constant NAME = "Eternal AI";
    string private constant SYMBOL = "MIND";

    uint8 private constant DECIMALS = 18;

    uint256 private _totalSupply;
    
    uint256 public constant FEEDENOMINATOR = 10_000;

    uint256 public buyFee = 4_000;
    uint256 public sellFee = 4_000;
    uint256 public transferFee = 0;
    uint256 public walletLimit = 200;
    uint256 public tradeStartTime = 0;
    uint256 public totalFeeCollected = 0;
    uint256 public totalFeeRedeemed = 0;
    uint256 public totalTriggerZeusBuyback = 0;
    uint256 public lastTriggerZeusTimestamp = 0;
    uint256 public minSwap = 10_000 ether;

    bool private constant ISMIND = true;

    bool public tradeEnabled = false;
    bool public isFeeActive = false;
    bool public isFeeLocked = false;
    bool public isSwapEnabled = false;
    bool public inSwap = false;
    bool public isWalletLimited = true;

    address public constant PROJECTOWNER = 0xe17e01EAA9A6Eca41dBD87161736a0D76F21995A;

    address public feeReceiver = 0x3D0829EAdE8AF8d9FeC3924dEf36970fDEA82462;

    address public pair;
    
    // MAPPING

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludeFromFees;
    mapping(address => bool) public isExcludeFromWalletLimits;
    mapping(address => bool) public isPairLP;

    // MODIFIER

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    // ERROR

    error InvalidTradeEnabledState(bool current);

    error InvalidFeeActiveState(bool current);

    error InvalidSwapEnabledState(bool current);

    error ExceedMaxFeeAllowed(uint256 limit);

    error ExceedWalletLimit(uint256 limit);

    error TradeDisabled();

    error FeeUpdateLocked();

    error WalletLimitRemoved();

    // CONSTRUCTOR

    constructor() Ownable (msg.sender) {
        _mint(msg.sender, 10_000_000 * 10**DECIMALS);

        router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());

        isPairLP[pair] = true;

        isExcludeFromFees[msg.sender] = true;
        isExcludeFromFees[address(router)] = true;

        isExcludeFromWalletLimits[msg.sender] = true;
        isExcludeFromWalletLimits[pair] = true;
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);

    event UpdateMinSwap(uint256 oldMinSwap, uint256 newMinSwap, address caller, uint256 timestamp);

    event UpdateFeeActive(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateFeeReceiver(address oldReceiver, address newReceiver, address caller, uint256 timestamp);

    event UpdateBuyFee(uint256 oldFee, uint256 newFee, address caller, uint256 timestamp);

    event UpdateSellFee(uint256 oldFee, uint256 newFee, address caller, uint256 timestamp);

    event UpdateTransferFee(uint256 oldFee, uint256 newFee, address caller, uint256 timestamp);

    event UpdateSwapEnabled(bool oldStatus, bool newStatus, address caller, uint256 timestamp);
        
    event AutoRedeem(uint256 feeDistribution, uint256 amountToRedeem, address caller, uint256 timestamp);

    event EnableTrading(address caller, uint256 timestamp);

    event ExcludeFromFees(bool oldStatus, bool newStatus, address caller, uint256 timestamp);
    
    event ExcludeFromWalletLimits(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event FeeLocked(address caller, uint256 timestamp);

    event RemoveWalletLimit(address caller, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}

    function enableTrading() external onlyOwner {
        if (tradeEnabled) { revert InvalidTradeEnabledState(tradeEnabled); }
        if (isFeeActive) { revert InvalidFeeActiveState(isFeeActive); }
        if (isSwapEnabled) { revert InvalidSwapEnabledState(isSwapEnabled); }
        tradeEnabled = true;
        isFeeActive = true;
        isSwapEnabled = true;
        tradeStartTime = block.timestamp;
        emit EnableTrading(msg.sender, tradeStartTime);
    }

    /* Redeem */

    function autoRedeem(uint256 amountToRedeem) public swapping {          
        totalFeeRedeemed += amountToRedeem;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), amountToRedeem);
        
        emit AutoRedeem(amountToRedeem, amountToRedeem, msg.sender, block.timestamp);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToRedeem,
            0,
            path,
            feeReceiver,
            block.timestamp
        );
    }

    /* Check */

    function isEternalAI() external pure returns (bool) {
        return ISMIND;
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0xdead)) - balanceOf(address(0));
    }

    function checkWalletLimit(uint256 amount, address to) public view {
        uint256 limit = totalSupply() * walletLimit / FEEDENOMINATOR;
        if (!isExcludeFromWalletLimits[to]) {
            if (balanceOf(to) + amount > limit) {
                revert ExceedWalletLimit(limit);
            }
        }
    }

    /* Update */

    function updateRouter(address newRouter) external onlyOwner {
        if (address(router) == newRouter) { revert CannotUseCurrentAddress(newRouter); }
        address oldRouter = address(router);
        router = IRouter(newRouter);
        
        isExcludeFromFees[newRouter] = true;

        emit UpdateRouter(oldRouter, newRouter, msg.sender, block.timestamp);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        isPairLP[pair] = true;
        if (isWalletLimited) {
            isExcludeFromWalletLimits[pair] = true;
        }
    }

    function updateMinSwap(uint256 newMinSwap) external onlyOwner {
        if (minSwap == newMinSwap) { revert CannotUseCurrentValue(newMinSwap); }
        uint256 oldMinSwap = minSwap;
        minSwap = newMinSwap;
        emit UpdateMinSwap(oldMinSwap, newMinSwap, msg.sender, block.timestamp);
    }

    function lockFee() external onlyOwner {
        if (isFeeLocked) { revert FeeUpdateLocked(); }
        isFeeLocked = true;
        emit FeeLocked(msg.sender, block.timestamp);
    }

    function removeWalletLimit() external onlyOwner {
        if (!isWalletLimited) { revert WalletLimitRemoved(); }
        isWalletLimited = false;
        emit RemoveWalletLimit(msg.sender, block.timestamp);
    }

    function updateFeeActive(bool newStatus) external onlyOwner {
        if (isFeeLocked) { revert FeeUpdateLocked(); }
        if (isFeeActive == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateFeeActive(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateBuyFee(uint256 newFee) external onlyOwner {
        if (isFeeLocked) { revert FeeUpdateLocked(); }
        if (newFee == buyFee) { revert CannotUseCurrentValue(newFee); }
        if (newFee > 4_000) { revert ExceedMaxFeeAllowed(4_000); }
        uint256 oldFee = buyFee;
        buyFee = newFee;
        emit UpdateBuyFee(oldFee, newFee, msg.sender, block.timestamp);
    }

    function updateSellFee(uint256 newFee) external onlyOwner {
        if (isFeeLocked) { revert FeeUpdateLocked(); }
        if (newFee == sellFee) { revert CannotUseCurrentValue(newFee); }
        if (newFee > 4_000) { revert ExceedMaxFeeAllowed(4_000); }
        uint256 oldFee = sellFee;
        sellFee = newFee;
        emit UpdateSellFee(oldFee, newFee, msg.sender, block.timestamp);
    }

    function updateTransferFee(uint256 newFee) external onlyOwner {
        if (isFeeLocked) { revert FeeUpdateLocked(); }
        if (newFee == transferFee) { revert CannotUseCurrentValue(newFee); }
        if (newFee > 4_000) { revert ExceedMaxFeeAllowed(4_000); }
        uint256 oldFee = transferFee;
        transferFee = newFee;
        emit UpdateTransferFee(oldFee, newFee, msg.sender, block.timestamp);
    }

    function updateFeeReceiver(address newReceiver) external onlyOwner {
        if (feeReceiver == newReceiver) { revert CannotUseCurrentAddress(newReceiver); }
        address oldReceiver = feeReceiver;
        feeReceiver = newReceiver;
        emit UpdateFeeReceiver(oldReceiver, newReceiver, msg.sender, block.timestamp);
    }

    function updateSwapEnabled(bool newStatus) external onlyOwner {
        if (isSwapEnabled == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isSwapEnabled;
        isSwapEnabled = newStatus;
        emit UpdateSwapEnabled(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function setExcludeFromFees(address user, bool newStatus) external onlyOwner {
        if (isExcludeFromFees[user] == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isExcludeFromFees[user];
        isExcludeFromFees[user] = newStatus;
        emit ExcludeFromFees(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function setExcludeFromWalletLimits(address user, bool newStatus) external onlyOwner {
        if (isExcludeFromWalletLimits[user] == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isExcludeFromWalletLimits[user];
        isExcludeFromWalletLimits[user] = newStatus;
        emit ExcludeFromWalletLimits(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function setPairLP(address lpPair, bool status) external onlyOwner {
        if (isPairLP[lpPair] == status) { revert CannotUseCurrentState(status); }
        if (IPair(lpPair).token0() != address(this) && IPair(lpPair).token1() != address(this)) { revert InvalidAddress(lpPair); }
        isPairLP[lpPair] = status;
    }

    /* Fee */

    function takeBuyFee(address from, uint256 amount, uint256 fee) internal swapping returns (uint256) {
        uint256 feeAmount = amount * fee / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        if (feeAmount > 0) {
            tallyCollection(from, feeAmount);
        }
        return newAmount;
    }

    function takeSellFee(address from, uint256 amount, uint256 fee) internal swapping returns (uint256) {
        uint256 feeAmount = amount * fee / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        if (feeAmount > 0) {
            tallyCollection(from, feeAmount);
        }
        return newAmount;
    }

    function takeTransferFee(address from, uint256 amount, uint256 fee) internal swapping returns (uint256) {
        uint256 feeAmount = amount * fee / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        if (feeAmount > 0) {
            tallyCollection(from, feeAmount);
        }
        return newAmount;
    }

    function tallyCollection(address from, uint256 collectFee) internal swapping {
        totalFeeCollected += collectFee;
        _basicTransfer(from, address(this), collectFee);
    }

    /* Buyback */

    function triggerZeusBuyback(uint256 amount) external onlyOwner {
        totalTriggerZeusBuyback += amount;
        lastTriggerZeusTimestamp = block.timestamp;
        buyTokens(amount, address(0xdead));
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        if (msg.sender == address(0xdead)) { revert InvalidAddress(address(0xdead)); }
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        } (0, path, to, block.timestamp);
    }

    /* ERC20 Standard */

    function name() external view virtual override returns (string memory) {
        return NAME;
    }
    
    function symbol() external view virtual override returns (string memory) {
        return SYMBOL;
    }
    
    function decimals() external view virtual override returns (uint8) {
        return DECIMALS;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) external virtual override returns (bool) {
        address provider = msg.sender;
        return _transfer(provider, to, amount);
    }
    
    function allowance(address provider, address spender) public view virtual override returns (uint256) {
        return _allowances[provider][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        return _transfer(from, to, amount);
    }
    
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, allowance(provider, spender) + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        address provider = msg.sender;
        uint256 currentAllowance = allowance(provider, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(provider, spender, currentAllowance - subtractedValue);
        }

        return true;
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) { revert InvalidAddress(account); }

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address provider, address spender, uint256 amount) internal virtual {
        if (provider == address(0)) { revert InvalidAddress(provider); }
        if (spender == address(0)) { revert InvalidAddress(spender); }

        _allowances[provider][spender] = amount;
        emit Approval(provider, spender, amount);
    }
    
    function _spendAllowance(address provider, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(provider, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(provider, spender, currentAllowance - amount);
            }
        }
    }

    /* Additional */

    function _basicTransfer(address from, address to, uint256 amount ) internal returns (bool) {
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }
    
    /* Overrides */
 
    function _transfer(address from, address to, uint256 amount) internal virtual returns (bool) {
        if (from == address(0)) { revert InvalidAddress(from); }
        if (to == address(0)) { revert InvalidAddress(to); }

        if (!tradeEnabled && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            revert TradeDisabled();
        }

        if (inSwap || isExcludeFromFees[from]) {
            return _basicTransfer(from, to, amount);
        }

        if (from != pair && isSwapEnabled && balanceOf(address(this)) >= minSwap && totalFeeCollected - totalFeeRedeemed >= minSwap) {
            autoRedeem(minSwap);
        }

        uint256 newAmount = amount;

        if (isFeeActive && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            newAmount = _beforeTokenTransfer(from, to, amount);
        }

        if (isWalletLimited) {
            checkWalletLimit(newAmount, to);
        }

        require(_balances[from] >= newAmount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = _balances[from] - newAmount;
            _balances[to] += newAmount;
        }

        emit Transfer(from, to, newAmount);

        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal swapping virtual returns (uint256) {        
        if (isPairLP[from]) {
            if (buyFee > 0) {
                return takeBuyFee(from, amount, buyFee);
            }
        }
        if (isPairLP[to]) {
            if (sellFee > 0) {
                return takeSellFee(from, amount, sellFee);
            }
        }
        if (!isPairLP[from] && !isPairLP[to]) {
            if (transferFee > 0) {
                return takeTransferFee(from, amount, transferFee);
            }
        }
        return amount;
    }
}