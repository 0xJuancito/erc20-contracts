/*
Welcome to Sword
----------------

Website: https://swordbot.online/

Whitepaper: https://sword-bot.gitbook.io/sword-bot/

Socials:
    - Telegram: https://t.me/sword_portal
    - Twitter: https://twitter.com/_swordbot

Sword Bot: https://t.me/Sword_Robot

*/
// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom( address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
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
}

contract SWORD is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balance;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _walletExcluded;
    uint8 private constant _decimals = 18;

    string private constant _name = "SWORD";
    string private constant _symbol = "SWORD";
    uint256 private constant _totalSupply = 10000000 * 10**_decimals;
    uint256 private constant minSwap = 4000 * 10**_decimals;
    uint256 private maxSwap = _totalSupply / 100;
    uint256 public maxTxAmount = _totalSupply / 100;
    uint256 public maxWalletAmount = _totalSupply / 100; 

    uint256 public buyTax = 20;
    uint256 public sellTax = 30;
    uint256 public splitF = 100;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;
    address payable private SwordWallet1;
    address payable private SwordWallet2;
    bool private launch = false;
    uint256 lastCaSell;

    bool private inSwap;
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(address[] memory wallets) {
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        SwordWallet1 = payable(wallets[0]);
        SwordWallet2 = payable(wallets[1]);
        _balance[msg.sender] = _totalSupply;
        for (uint256 i = 0; i < wallets.length; i++) {
            _walletExcluded[wallets[i]] = true;
        }
        _walletExcluded[msg.sender] = true;
        _walletExcluded[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    function transfer(address recipient, uint256 amount)public override returns (bool){
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256){
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool){
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender,_msgSender(),_allowances[sender][_msgSender()].sub(amount,"ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function enableTrading() external onlyOwner {
        launch = true;
    }

    function setExcludedWallet(address wallet, bool exclude) external onlyOwner {
        _walletExcluded[wallet] = exclude;
    }

    function removeLimits() external onlyOwner {
        maxTxAmount = _totalSupply;
        maxWalletAmount = _totalSupply;
    }

    /**
     * @param newMaxTxAmount set amount without decimals
     * @param newMaxWalletAmount set amount without decimals
     */
    function setLimits(uint256 newMaxTxAmount, uint256 newMaxWalletAmount) external onlyOwner {
        maxTxAmount = newMaxTxAmount * 10**_decimals;
        maxWalletAmount = newMaxWalletAmount * 10**_decimals;
    }

    function changeTax(uint256 newBuyTaxSW, uint256 newSellTaxSW, uint256 newSplitPercentF) external onlyOwner {
        buyTax = newBuyTaxSW;
        sellTax = newSellTaxSW;
        splitF = newSplitPercentF;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(amount > 0, "transfer zero amount");
        require(from != address(0), "ERC20: transfer from the zero address");
        uint256 _tax;
        if (_walletExcluded[from] || _walletExcluded[to]) {
            _tax = 0;
        } else {
            require(launch, "Trading not open");
            require(amount <= maxTxAmount, "MaxTx Enabled at launch");
            if (from == uniswapV2Pair) {
                require(balanceOf(to) + amount <= maxWalletAmount);
                _tax = buyTax;
            } else if (to == uniswapV2Pair) {
                _tax = sellTax;
                uint256 tokensToSwap = balanceOf(address(this));
                if (tokensToSwap > minSwap && !inSwap && lastCaSell != block.number) {
                    swapTokensForEth(tokensToSwap > maxSwap ? maxSwap : tokensToSwap);
                    lastCaSell = block.number;
                }
            } else {
                _tax = 0;
            }
        }
        //updating balances
        _balance[from] = _balance[from] - amount;
        if(_tax > 0){
            uint256 taxTokens = (amount * _tax) / 100;
            _balance[address(this)] = _balance[address(this)] + taxTokens;
            amount = amount - taxTokens;
        }
        _balance[to] = _balance[to] + amount;
        emit Transfer(from, to, amount);
    }

    /**
     * @param percentMaxSwap use percent value: 1, 3, 15, ...
     */
    function setMaxCaSwap(uint256 percentMaxSwap) external onlyOwner {
        maxSwap = (totalSupply()*percentMaxSwap)/100;
    }
  
    /**
     * @dev use for manual send eth from contract to recipient
     */
    function manualSendBalance(address recipient) external {
        require(_msgSender() == SwordWallet1);
        payable(recipient).transfer(address(this).balance);
    }

    function manualSwapTokens() external {
        require(_msgSender() == SwordWallet1);
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        //Splitting
        uint256 transferEth = (address(this).balance * splitF)/100;
        if(transferEth > 0){
            SwordWallet1.transfer(transferEth);
        }
        transferEth = address(this).balance;
        if(transferEth > 0){
            SwordWallet2.transfer(transferEth);
        }
    }
    receive() external payable {}
}