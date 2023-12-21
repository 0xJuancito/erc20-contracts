/**
    Alcatraz
    Your fortress for secure liquidity. Making crypto safe for everyone and returning 
    profits to our token holders.
    
    Website: alcatraz.tech
    Telegram: t.me/alcatrazportal
    Twitter: twitter.com/Alcatraztech
**/

// SPDX-License-Identifier: No License

pragma solidity 0.8.21;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract Alcatraz is ERC20, Ownable {

  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  uint256 public constant MAX_SUPPLY = 2_000_000e18;

  bool private swapping;

  address public revShareWallet;
  address public marketingWallet;
  address public lpTokensReceiver;

  uint256 public maxTransactionAmount = (MAX_SUPPLY * 1) / 100; // 1%
  uint256 public swapTokensAtAmount = (MAX_SUPPLY * 5) / 10000; // 0.05%
  uint256 public maxWallet = (MAX_SUPPLY * 1) / 100; // 1%

  bool public limitsInEffect = true;
  bool public swapEnabled = false;

  bool public botCheckEnabled = true;

  // Anti-bot and anti-whale mappings and variables
  mapping(address => bool) bots;

  uint256 public constant taxRate = 4; // 4% of buy and sell
  uint256 public constant revenueShare = 1; // 1%
  uint256 public constant marketingShare = 2; // 2%
  uint256 public constant liquidityShare = 1; // 1%

  /******************/

  // exclude from fees and max transaction amount
  mapping(address => bool) private _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
  // could be subject to a maximum transfer amount
  mapping(address => bool) public automatedMarketMakerPairs;

  event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
  event ExcludeFromFees(address indexed account, bool isExcluded);
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
  event revShareWalletUpdated(address indexed newWallet, address indexed oldWallet);
  event marketingWalletUpdated(address indexed newWallet, address indexed oldWallet);
  event lpTokensReceiverUpdated(address indexed newWallet, address indexed oldWallet);
  event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

  constructor(address revWallet, address marWallet, address lpReceiverWallet) ERC20('Alcatraz', 'ALCZ') {

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    excludeFromMaxTransaction(address(_uniswapV2Router), true);
    uniswapV2Router = _uniswapV2Router;

    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
    excludeFromMaxTransaction(address(uniswapV2Pair), true);
    _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

    revShareWallet = revWallet;
    marketingWallet = marWallet;
    lpTokensReceiver = lpReceiverWallet;

    // exclude from paying fees or having max transaction amount
    excludeFromFees(owner(), true);
    excludeFromFees(address(this), true);

    excludeFromMaxTransaction(owner(), true);
    excludeFromMaxTransaction(address(this), true);

    /*
        _mint is an internal function in ERC20.sol that is only called here,
        and CANNOT be called ever again
    */
    _mint(msg.sender, MAX_SUPPLY);
  }

  receive() external payable {}

  // remove limits after token is stable
  function removeLimits() external onlyOwner {
    limitsInEffect = false;
  }

  // change the minimum amount of tokens to sell from fees
  function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
    require(newAmount >= (totalSupply() * 1) / 100000, 'Swap amount cannot be lower than 0.001% total supply.');
    require(newAmount <= (totalSupply() * 5) / 1000, 'Swap amount cannot be higher than 0.5% total supply.');
    swapTokensAtAmount = newAmount;
  }

  function updateMaxTxnAmount(uint256 newNum) external onlyOwner {
    require(newNum >= ((totalSupply() * 5) / 1000) / 1e18, 'Cannot set maxTransactionAmount lower than 0.5%');
    maxTransactionAmount = newNum * (10 ** 18);
  }

  function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
    require(newNum >= ((totalSupply() * 10) / 1000) / 1e18, 'Cannot set maxWallet lower than 1.0%');
    maxWallet = newNum * (10 ** 18);
  }

  function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
    _isExcludedMaxTransactionAmount[updAds] = isEx;
  }

  // only use to disable contract sales if absolutely necessary (emergency use only)
  function updateSwapEnabled(bool enabled) external onlyOwner {
    swapEnabled = enabled;
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
    require(pair != uniswapV2Pair, 'The pair cannot be removed from automatedMarketMakerPairs');

    _setAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
    automatedMarketMakerPairs[pair] = value;

    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateRevShareWallet(address newRevShareWallet) external onlyOwner {
    emit revShareWalletUpdated(newRevShareWallet, revShareWallet);
    revShareWallet = newRevShareWallet;
  }

  function updateMarketingWallet(address newWallet) external onlyOwner {
    emit marketingWalletUpdated(newWallet, marketingWallet);
    marketingWallet = newWallet;
  }

  function setLpTokensReceiver(address newWallet) public onlyOwner {
    emit lpTokensReceiverUpdated(newWallet, lpTokensReceiver);
    lpTokensReceiver = newWallet;
  }

  function isExcludedFromFees(address account) public view returns (bool) {
    return _isExcludedFromFees[account];
  }

  function isBot(address account) public view returns (bool) {
    return bots[account];
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0), 'TOKEN: transfer from the zero address');
    require(to != address(0), 'TOKEN: transfer to the zero address');
    require(!bots[from] && !bots[to], "TOKEN: Nasty bot, ain't you!");

    if (amount == 0) {
      super._transfer(from, to, 0);
      return;
    }

    if (limitsInEffect) {
      if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !swapping) {

        //when buy
        if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
          require(amount <= maxTransactionAmount, 'Buy transfer amount exceeds the maxTransactionAmount.');
          require(amount + balanceOf(to) <= maxWallet, 'Max wallet exceeded');
        }
        //when sell
        else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
          require(amount <= maxTransactionAmount, 'Sell transfer amount exceeds the maxTransactionAmount.');
        } else if (!_isExcludedMaxTransactionAmount[to]) {
          require(amount + balanceOf(to) <= maxWallet, 'Max wallet exceeded');
        }
      }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= swapTokensAtAmount;

    if (
      canSwap &&
      swapEnabled &&
      !swapping &&
      !automatedMarketMakerPairs[from] &&
      !_isExcludedFromFees[from] &&
      !_isExcludedFromFees[to]
    ) {
      swapping = true;

      swapBack();

      swapping = false;
    }

    bool takeFee = !swapping;

    // if any account belongs to _isExcludedFromFee account then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;
    // only take fees on buys/sells, do not take on wallet transfers
    if (takeFee) {
      // on sell
      if (automatedMarketMakerPairs[to] && taxRate > 0) {
        fees = (amount * taxRate) / 100;
      }
      // on buy
      else if (automatedMarketMakerPairs[from] && taxRate > 0) {
        fees = (amount * taxRate) / 100;
      }

      if (fees > 0) {
        super._transfer(from, address(this), fees);
      }

      amount -= fees;
    }

    super._transfer(from, to, amount);
  }

  function swapTokensForEth(uint256 tokenAmount) private {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // make the swap
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // approve token transfer to cover all possible scenarios
    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // add the liquidity
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      lpTokensReceiver,
      block.timestamp
    );
  }

  function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));
    bool success;

    if (contractBalance == 0) {
      return;
    }

    if (contractBalance > swapTokensAtAmount * 20) {
      contractBalance = swapTokensAtAmount * 20;
    }

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (contractBalance * liquidityShare) / taxRate / 2;
    uint256 amountToSwapForETH = contractBalance - liquidityTokens;

    uint256 initialETHBalance = address(this).balance;

    swapTokensForEth(amountToSwapForETH);

    uint256 ethBalance = address(this).balance - initialETHBalance;

    uint256 ethForRevShare = (ethBalance * revenueShare) / (taxRate - (liquidityShare / 2));

    uint256 ethForMarketing = (ethBalance * marketingShare) / (taxRate - (liquidityShare / 2));

    uint256 ethForLiquidity = ethBalance - ethForRevShare - ethForMarketing;

    (success, ) = address(marketingWallet).call{ value: ethForMarketing }('');

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
      addLiquidity(liquidityTokens, ethForLiquidity);
      emit SwapAndLiquify(amountToSwapForETH, ethForLiquidity, liquidityShare);
    }

    (success, ) = address(revShareWallet).call{ value: address(this).balance }('');
  }

  function withdrawStuckToken(address _token, address _to) external onlyOwner {
    require(_token != address(0), '_token address cannot be 0');
    uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
    IERC20(_token).transfer(_to, _contractBalance);
  }

  function withdrawStuckEth(address toAddr) external onlyOwner {
    (bool success, ) = toAddr.call{ value: address(this).balance }('');
    require(success);
  }

  // @dev team renounce blacklist commands
  function removeBotCheck() public onlyOwner {
    botCheckEnabled = false;
  }

  function blockBot(address _addr, bool yourOut) public onlyOwner {
    require(botCheckEnabled, 'Team has revoked bot check');
    require(
      _addr != address(uniswapV2Pair) && _addr != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D),
      "Cannot blacklist token's v2 router or v2 pool."
    );
    bots[_addr] = yourOut;
  }

  // @dev unblock address; not affected by botCheckEnabled incase team mistakenly blocked real address
  function unblockBot(address _addr) public onlyOwner {
    bots[_addr] = false;
  }
}
