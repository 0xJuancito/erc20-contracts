// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

/*        

Reserve ($RSRV)
https://www.reserveth.com/
https://t.me/rsrv_eth
https://twitter.com/rsrv_eth

*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IRSRV.sol";

contract ReserveToken is Context, IERC20, IRSRV, Ownable {
  using Address for address payable;
  using SafeMath for uint;

  mapping (address => uint) private _balances;
  mapping (address => mapping (address => uint)) private _allowances;

  mapping (address => bool) private _isExcludedFromFee;

  address private constant _deadAddress = address(0xdead);
  address payable private _taxWallet;

  uint private _initialBuyTax = 3000; // 30.00%
  uint private _initialSellTax = 3000;
  uint private _finalBuyTax = 200; // 2.00%
  uint private _finalSellTax = 200;
  uint private _reduceBuyTaxAfter = 20;
  uint private _reduceSellTaxAfter = 20;
  uint private _preventSwapBefore = 20;

  string private constant _name = "Reserve";
  string private constant _symbol = "RSRV";
  uint8 private constant _decimals = 18;
  uint private _totalSupply = 625_000 * 10**_decimals;

  uint public _maxTxAmount = 300; // 3.0%
  uint public _maxWalletSize = 300; // 3.0%
  uint public _swapThreshold = 10; // 0.1%

  address public uniswapV2Router;
  address public uniswapV2Pair;
  address public reserve;
  address public brokerage;

  bool private tradingOpen;
  uint public launchBlock;

  bool private inSwap = false;
  bool private swapEnabled = false;

  event MaxTxAmountUpdated(uint _maxTxAmount);

  modifier lockTheSwap {
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor (
    address taxWallet
  ) {
    _taxWallet = payable(taxWallet);
    _balances[_msgSender()] = _totalSupply;

    _isExcludedFromFee[_msgSender()] = true;
    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[_taxWallet] = true;
    _isExcludedFromFee[_deadAddress] = true;

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

  function totalSupply() public view override returns (uint) {
    return _totalSupply;
  }

  function balanceOf(address account) public view override returns (uint) {
    return _balances[account];
  }

  function transfer(address recipient, uint amount) public override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view override returns (uint) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint amount) public override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function mint(uint amount) external {
    require (_msgSender() == reserve || _msgSender() == brokerage, "Only the reserve and brokerage are allowed to mint tokens");
    _balances[reserve] = _balances[reserve].add(amount);
    _totalSupply = _totalSupply.add(amount);
    emit Transfer(address(0), reserve, amount);
  }

  function maxTxAmount() public view returns (uint) {
    return _totalSupply.mul(_maxTxAmount).div(10000);
  }

  function maxWalletSize() public view returns (uint) {
    return _totalSupply.mul(_maxWalletSize).div(10000);
  }

  function swapThreshold() public view returns (uint) {
    return _totalSupply.mul(_swapThreshold).div(10000);
  }

  function _approve(address owner, address spender, uint amount) private {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(address from, address to, uint amount) private {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "Transfer amount must be greater than zero");

    uint taxAmount;

    if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
      require (tradingOpen, "Trading is not enabled yet");

      if (from == uniswapV2Pair && to != address(uniswapV2Router) && !_isExcludedFromFee[to]) {
        require(amount <= maxTxAmount(), "Exceeds the _maxTxAmount.");
        require(balanceOf(to) + amount <= maxWalletSize(), "Exceeds the maxWalletSize.");
      }

      taxAmount = amount.mul((block.number > launchBlock + _reduceBuyTaxAfter) ? _finalBuyTax : _initialBuyTax).div(10000);
      if (to == uniswapV2Pair && from != address(this)) {
        require(amount <= maxTxAmount(), "Exceeds the _maxTxAmount.");
        taxAmount = amount.mul((block.number > launchBlock + _reduceSellTaxAfter) ? _finalSellTax : _initialSellTax).div(10000);
      }

      uint contractTokenBalance = balanceOf(address(this));
      if (!inSwap && to == uniswapV2Pair && swapEnabled && contractTokenBalance > swapThreshold() && block.number > launchBlock + _preventSwapBefore) {
        swapTokensForEth(swapThreshold());
        uint contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
          sendETHToFee(address(this).balance);
        }
      }
    }

    if (taxAmount > 0) {
      _balances[address(this)] = _balances[address(this)].add(taxAmount);
      emit Transfer(from, address(this), taxAmount);
    }

    _balances[from] = _balances[from].sub(amount);
    _balances[to] = _balances[to].add(amount.sub(taxAmount));

    emit Transfer(from, to, amount.sub(taxAmount));
  }

  function min(uint a, uint b) private pure returns (uint) {
    return (a > b) ? b : a;
  }

  function swapTokensForEth(uint tokenAmount) private lockTheSwap {
    if (tokenAmount == 0) return;
    if (!tradingOpen) return;

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = IUniswapV2Router02(uniswapV2Router).WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    IUniswapV2Router02(uniswapV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function sendETHToFee(uint amount) private {
    Address.sendValue(payable(_taxWallet), amount);
  }

  function initPair() external onlyOwner {
    require (uniswapV2Pair == address(0), "Pair is already initialized");
    uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswapV2Router);
    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
  }

  function openTrading() external payable onlyOwner {
    require (uniswapV2Pair != address(0), "Pair has not been initialized yet");
    require (!tradingOpen, "Trading is already open");
    require (balanceOf(_msgSender()) > 0, "No token balance");
    require (msg.value > 0, "No eth value");

    uint tokenAmount = balanceOf(_msgSender());

    _approve(_msgSender(), address(this), tokenAmount);
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    _transfer(_msgSender(), address(this), tokenAmount);

    IUniswapV2Router02(uniswapV2Router).addLiquidityETH{value: msg.value}(
      address(this),
      tokenAmount,
      0,
      0,
      _msgSender(),
      block.timestamp
    );

    swapEnabled = true;
    tradingOpen = true;
    launchBlock = block.number;
  }

  function setIsExcluded(address account, bool _isExcluded) external onlyOwner {
    _isExcludedFromFee[account] = _isExcluded;
  }

  function setReserve(address _reserve) external onlyOwner {
    require (_reserve != address(0), "Invalid reserve address");
    _isExcludedFromFee[reserve] = false;
    reserve = _reserve;
    _isExcludedFromFee[_reserve] = true;
  }

  function setBrokerage(address _brokerage) external onlyOwner {
    require (_brokerage != address(0), "Invalid brokerage address");
    _isExcludedFromFee[brokerage] = false;
    brokerage = _brokerage;
    _isExcludedFromFee[_brokerage] = true;
  }

  function removeLimits() external onlyOwner {
    _maxTxAmount = 10000;
    _maxWalletSize = 10000;
  }

  function rescueETH() external {
    require (_msgSender() == _taxWallet, "Not authorized");
    payable(_msgSender()).sendValue(address(this).balance);
  }
 
  function rescueTokens(address _token) external {
    require (_msgSender() == _taxWallet, "Not authorized");
    require (_token != address(this), "Can not rescue own token!");
    IERC20(_token).transfer(_msgSender(), IERC20(_token).balanceOf(address(this)));
  }

  receive() external payable {}
}