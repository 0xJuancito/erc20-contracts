/*

 $$$$$$\            $$\   $$\                         $$\                           
$$$ __$$\           $$$\  $$ |                        $$ |                          
$$$$\ $$ |$$\   $$\ $$$$\ $$ |$$\   $$\ $$$$$$\$$$$\  $$$$$$$\   $$$$$$\   $$$$$$\  
$$\$$\$$ |\$$\ $$  |$$ $$\$$ |$$ |  $$ |$$  _$$  _$$\ $$  __$$\ $$  __$$\ $$  __$$\ 
$$ \$$$$ | \$$$$  / $$ \$$$$ |$$ |  $$ |$$ / $$ / $$ |$$ |  $$ |$$$$$$$$ |$$ |  \__|
$$ |\$$$ | $$  $$<  $$ |\$$$ |$$ |  $$ |$$ | $$ | $$ |$$ |  $$ |$$   ____|$$ |      
\$$$$$$  /$$  /\$$\ $$ | \$$ |\$$$$$$  |$$ | $$ | $$ |$$$$$$$  |\$$$$$$$\ $$ |      
 \______/ \__/  \__|\__|  \__| \______/ \__| \__| \__|\_______/  \_______|\__|      
                                                                                   

Telegram Bot: https://t.me/OxNumber_bot
Telegram: https://t.me/OxNumber
Twitter: https://twitter.com/0xNumberEth
Website: https://0xnumber.io

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;


    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }


    function name() public view virtual override returns (string memory) {
        return _name;
    }

 
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

  
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

 
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

   
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }


    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

 
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

  
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

 
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

   
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}



abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() {
        _transferOwnership(_msgSender());
    }

  
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

  
    function owner() public view virtual returns (address) {
        return _owner;
    }


    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

 
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

   
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address UNISWAP_V2_PAIR);
}

contract OxNumber is IERC20, Ownable {
    event Reflect(uint256 amountReflected, uint256 newTotalProportion);


    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public immutable UNISWAP_V2_PAIR;

    struct Fee {
        uint8 reflection;
        uint8 dev;
        uint128 total;
    }

    string _name = "0xNumber";
    string _symbol = "OxN"; 

    uint256 _totalSupply = 10000000 * 10 ** 18;
    address private marketingWallet;

    uint256 public _maxTxAmount = (_totalSupply * 2) / 100;
    uint256 public _maxWalletSize =  (_totalSupply * 2) / 100; 
    mapping(address => uint256) public _rOwned;
    uint256 public _totalProportion = _totalSupply;

    mapping(address => mapping(address => uint256)) _allowances;

    bool public limitsEnabled = true;
    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isTxLimitExempt;

    Fee public initialBuyFee = Fee({ reflection: 0, dev: 33, total: 33});
    Fee public initialSellFee = Fee({ reflection: 0, dev: 33, total: 33});
    Fee public finalBuyFee = Fee({ reflection: 1, dev: 4, total: 5});
    Fee public finalSellFee =  Fee({ reflection: 1, dev: 4, total: 5});
    Fee public buyFee;
    Fee public sellFee;
    address private devWallet;

    bool public claimingFees = true;
    uint256 public swapThreshold = (_totalSupply * 5) / 10000; // 0.05%
    uint256 public customMultiplier = 20;
    bool inSwap;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }


    constructor(address _devWallet, address _marketingWallet) {
        buyFee = initialBuyFee;
        sellFee = initialSellFee;
        address _uniswapPair =
            IUniswapV2Factory(UNISWAP_V2_ROUTER.factory()).createPair(address(this), UNISWAP_V2_ROUTER.WETH());
        UNISWAP_V2_PAIR = _uniswapPair;
      
        _allowances[address(this)][address(UNISWAP_V2_ROUTER)] = type(uint256).max;
        _allowances[address(this)][tx.origin] = type(uint256).max;

        isTxLimitExempt[address(this)] = true;
        isTxLimitExempt[address(UNISWAP_V2_ROUTER)] = true;
        isTxLimitExempt[_uniswapPair] = true;
        isTxLimitExempt[tx.origin] = true;
        isFeeExempt[tx.origin] = true;
        isFeeExempt[address(this)] = true;
        marketingWallet = _marketingWallet;

        isFeeExempt[marketingWallet] = true;
        isTxLimitExempt[marketingWallet] = true;

        devWallet = _devWallet;
    uint256 marketingWalletSupply = _totalSupply / 3; // 3% of total supply
    _rOwned[marketingWallet] = marketingWalletSupply;

    // Allocate the remaining supply to the tx.origin
    _rOwned[tx.origin] = _totalSupply - marketingWalletSupply;

    // Emit transfer events
    emit Transfer(address(0), marketingWallet, marketingWalletSupply);
    emit Transfer(address(0), tx.origin, _rOwned[tx.origin]);
}

    receive() external payable {}

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }
    function setFees(uint8 buyReflection, uint8 buyDev, uint8 sellReflection, uint8 sellDev) public onlyOwner {
        buyFee = Fee({reflection: buyReflection, dev: buyDev, total: uint128(buyReflection) + uint128(buyDev)});
        sellFee = Fee({reflection: sellReflection, dev: sellDev, total: uint128(sellReflection) + uint128(sellDev)});
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "ERC20: insufficient allowance");
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }

        return _transferFrom(sender, recipient, amount);
    }


    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function tokensToProportion(uint256 tokens) public view returns (uint256) {
        return tokens * _totalProportion / _totalSupply;
    }

    function tokenFromReflection(uint256 proportion) public view returns (uint256) {
        return proportion * _totalSupply / _totalProportion;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(DEAD) - balanceOf(ZERO);
    }


    function clearStuckBalance() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    function clearStuckToken() external onlyOwner {
        _transferFrom(address(this), msg.sender, balanceOf(address(this)));
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external onlyOwner {
        claimingFees = _enabled;
        swapThreshold =  (_totalSupply * _amount) / 10000;
    }

  function setCustomMultiplier(uint256 _customMultiplier) public onlyOwner {
        customMultiplier = _customMultiplier;
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }

    function setFeeReceivers(address m_) external onlyOwner {
        devWallet = m_;
    }

    function setMaxTxBasisPoint(uint256 p_) external onlyOwner {
        _maxTxAmount = _totalSupply * p_ / 10000;
    }

    function removeLimits() external onlyOwner {
        limitsEnabled = false;
        buyFee = finalBuyFee;
        sellFee = finalSellFee;
    }

    
   function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
    if (inSwap) {
        return _basicTransfer(sender, recipient, amount);
    }


    if (limitsEnabled && sender == UNISWAP_V2_PAIR && !isTxLimitExempt[recipient]) {
        require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            require(balanceOf(recipient) + amount <= _maxWalletSize, "Exceeds maxWalletSize.");
        }
    if (_shouldSwapBack()) {
        _swapBack();
    }

    uint256 proportionAmount = tokensToProportion(amount);
    require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
    _rOwned[sender] = _rOwned[sender] - proportionAmount;


    uint256 proportionReceived = _shouldTakeFee(sender, recipient)
        ? _takeFeeInProportions(sender == UNISWAP_V2_PAIR ? true : false, sender, proportionAmount)
        : proportionAmount;
    _rOwned[recipient] = _rOwned[recipient] + proportionReceived;

    emit Transfer(sender, recipient, tokenFromReflection(proportionReceived));
    return true;
    }
 
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 proportionAmount = tokensToProportion(amount);
        require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
        _rOwned[sender] = _rOwned[sender] - proportionAmount;
        _rOwned[recipient] = _rOwned[recipient] + proportionAmount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    
    function _takeFeeInProportions(bool buying, address sender, uint256 proportionAmount) internal returns (uint256) {
        Fee memory __buyFee = buyFee;
        Fee memory __sellFee = sellFee;

        uint256 proportionFeeAmount =
            buying == true ? proportionAmount * __buyFee.total / 100 : proportionAmount * __sellFee.total / 100;


        uint256 proportionReflected = buying == true
            ? proportionFeeAmount * __buyFee.reflection / __buyFee.total
            : proportionFeeAmount * __sellFee.reflection / __sellFee.total;

        _totalProportion = _totalProportion - proportionReflected;

       
        uint256 _proportionToContract = proportionFeeAmount - proportionReflected;
        if (_proportionToContract > 0) {
            _rOwned[address(this)] = _rOwned[address(this)] + _proportionToContract;

            emit Transfer(sender, address(this), tokenFromReflection(_proportionToContract));
        }
        emit Reflect(proportionReflected, _totalProportion);
        return proportionAmount - proportionFeeAmount;
    }

    function _shouldSwapBack() internal view returns (bool) {
        return msg.sender != UNISWAP_V2_PAIR && !inSwap && claimingFees && balanceOf(address(this)) >= swapThreshold;
    }

    function _swapBack() internal swapping {
        Fee memory __sellFee = sellFee;
        uint256 contractBalance = balanceOf(address(this));
        uint256 __swapThreshold = swapThreshold;
        uint256 amountToSwap = __swapThreshold;

        if (contractBalance == 0 || amountToSwap == 0) {
            return;
        }

        if (contractBalance > swapThreshold * customMultiplier) {
            contractBalance = swapThreshold * customMultiplier;
        }
        approve(address(UNISWAP_V2_ROUTER), contractBalance);


        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractBalance, 0, path, address(this), block.timestamp
        );

        uint256 amountETH = address(this).balance;

        uint256 totalSwapFee = __sellFee.total - __sellFee.reflection;
        uint256 devcash = amountETH * __sellFee.dev / totalSwapFee;


     (bool tmpSuccess,) = payable(devWallet).call{value: devcash}("");
    require(tmpSuccess, "Transfer failed.");

    }

    function _shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }
}