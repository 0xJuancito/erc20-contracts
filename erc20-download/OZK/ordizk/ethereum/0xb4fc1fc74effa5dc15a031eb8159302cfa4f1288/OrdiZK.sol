/*
    https://ordizk.io
    https://ordizk.gitbook.io
    https://x.com/OrdiZK_
    https://t.me/ordizk
    https://t.me/ordizk_bridge_bot
*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
    error NotOwner();

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_owner != msg.sender) revert NotOwner();
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract OrdiZK is IERC20, Ownable {
    error TradingAlreadyOpen();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroValue();
    error ZeroToken();
    error TaxTooHigh();
    error NotSelf();
    error Unauthorized();

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private bots;
    address payable private _taxWallet;
    uint256 private _firstBlock;

    uint256 private _initialBuyTax = 30;
    uint256 private _initialSellTax = 45;
    uint256 private _finalBuyTax = 5;
    uint256 private _finalSellTax = 5;
    uint256 private _reduceBuyTaxAt = 24;
    uint256 private _reduceSellTaxAt = 30;
    uint256 private _preventSwapBefore = 20;
    uint256 private _buyCount = 0;

    uint8 private constant _DECIMALS = 9;
    uint256 private constant _TOTAL = 1000000000 * 10 ** _DECIMALS;
    string private constant _NAME = unicode"OrdiZK";
    string private constant _SYMBOL = unicode"OZK";
    uint256 public maxTx = 20000000 * 10 ** _DECIMALS;
    uint256 public maxWallet = 20000000 * 10 ** _DECIMALS;
    uint256 public swapThreshold = 10000000 * 10 ** _DECIMALS;
    uint256 public maxTaxSwap = 10000000 * 10 ** _DECIMALS;

    IUniswapV2Router02 private constant _UNISWAP_V2_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private _uniswapV2Pair;
    bool public lpAdded;
    bool private _inSwap = false;
    bool private _swapEnabled = false;

    event MaxTxAmountUpdated(uint256 maxTx);

    constructor() {
        _taxWallet = payable(msg.sender);
        _balances[msg.sender] = _TOTAL;

        _isExcludedFromLimits[tx.origin] = true;
        _isExcludedFromLimits[address(0)] = true;
        _isExcludedFromLimits[address(0xdead)] = true;
        _isExcludedFromLimits[address(this)] = true;
        _isExcludedFromLimits[address(_UNISWAP_V2_ROUTER)] = true;

        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[tx.origin] = true;

        emit Transfer(address(0), msg.sender, _TOTAL);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _NAME;
    }

    function symbol() public pure returns (string memory) {
        return _SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() public pure override returns (uint256) {
        return _TOTAL;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        if (owner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        require(!bots[from] && !bots[to], "shoo");

        if (maxWallet != _TOTAL && !_isExcludedFromLimits[to]) {
            require(balanceOf(to) + amount <= maxWallet, "Exceeds maxWalletSize");
        }

        if (maxTx != _TOTAL && !_isExcludedFromLimits[from]) {
            require(amount <= maxTx, "Exceeds maxTx");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (
            !_inSwap && contractTokenBalance >= swapThreshold && _swapEnabled && _buyCount > _preventSwapBefore
                && to == _uniswapV2Pair && !_isExcludedFromFee[from]
        ) {
            _swapTokensForEth(_min(amount, _min(contractTokenBalance, maxTaxSwap)));
            uint256 contractETHBalance = address(this).balance;
            if (contractETHBalance > 0) {
                _sendETHToFee(contractETHBalance);
            }
        }

        uint256 taxAmount = 0;
        if (!_inSwap && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            // sell
            if (to == _uniswapV2Pair) {
                taxAmount = (amount * ((_buyCount > _reduceSellTaxAt) ? _finalSellTax : _initialSellTax)) / 100;
            }
            // buy
            else if (from == _uniswapV2Pair) {
                if (_firstBlock + 25 > block.number) {
                    require(!_isContract(to), "contract");
                }
                taxAmount = (amount * ((_buyCount > _reduceBuyTaxAt) ? _finalBuyTax : _initialBuyTax)) / 100;
                ++_buyCount;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)] + taxAmount;
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] = _balances[from] - amount;
        _balances[to] = _balances[to] + amount - taxAmount;
        emit Transfer(from, to, amount - taxAmount);
    }

    function removeLimits() external onlyOwner {
        maxTx = _TOTAL;
        maxWallet = _TOTAL;
        emit MaxTxAmountUpdated(_TOTAL);
    }

    function setBots(address[] memory bots_, bool isBot_) public onlyOwner {
        for (uint256 i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = isBot_;
        }
    }

    function openTrading(uint256 amount) external payable onlyOwner {
        if (lpAdded) revert TradingAlreadyOpen();
        if (msg.value == 0) revert ZeroValue();
        if (amount == 0) revert ZeroToken();
        _transfer(msg.sender, address(this), amount);
        _approve(address(this), address(_UNISWAP_V2_ROUTER), _TOTAL);

        _uniswapV2Pair =
            IUniswapV2Factory(_UNISWAP_V2_ROUTER.factory()).createPair(address(this), _UNISWAP_V2_ROUTER.WETH());
        _isExcludedFromLimits[_uniswapV2Pair] = true;

        _UNISWAP_V2_ROUTER.addLiquidityETH{value: address(this).balance}(
            address(this), balanceOf(address(this)), 0, 0, owner(), block.timestamp
        );
        IERC20(_uniswapV2Pair).approve(address(_UNISWAP_V2_ROUTER), type(uint256).max);
        _swapEnabled = true;
        lpAdded = true;
        _firstBlock = block.number;
    }

    function lowerTaxes(uint256 buyTax_, uint256 sellTax_) external onlyOwner {
        if (buyTax_ > _finalBuyTax) { revert TaxTooHigh(); }
        if (sellTax_ > _finalSellTax) { revert TaxTooHigh(); }

        _finalBuyTax = buyTax_;
        _finalSellTax = sellTax_;
    }

    function clearStuck() external {
        (bool success,) = _taxWallet.call{value: address(this).balance}("");
        require(success);
    }

    function clearStuckSelf() external {
        if (msg.sender != _taxWallet) { revert Unauthorized(); }
        _transfer(address(this), _taxWallet, balanceOf(address(this)));
    }

    function clearStuckToken(address token) external {
        if (token == address(this)) { revert NotSelf(); }
        IERC20(token).transfer(_taxWallet, IERC20(token).balanceOf(address(this)));
    }

    function isBot(address a) public view returns (bool) {
        return bots[a];
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
        _inSwap = true;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _UNISWAP_V2_ROUTER.WETH();
        _approve(address(this), address(_UNISWAP_V2_ROUTER), tokenAmount);
        _UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, 0, path, address(this), block.timestamp
        );
        _inSwap = false;
    }

    function _sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }
}