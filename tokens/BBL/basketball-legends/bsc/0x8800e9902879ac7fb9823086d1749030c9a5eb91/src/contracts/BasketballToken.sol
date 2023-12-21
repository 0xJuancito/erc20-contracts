// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Authorized.sol";
import "./IPancake.sol";
import "./SwapHelper.sol";

contract BasketballToken is Authorized, ERC20 {
  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ZERO = 0x0000000000000000000000000000000000000000;
  address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  string constant _name = "BASKETBALL LEGENDS";
  string constant _symbol = "BBL";

  // Token supply control
  uint8 constant decimal = 18;
  uint8 constant decimalBUSD = 18;  
  uint256 constant maxSupply = 48_000_000 * (10 ** decimal);
  
  uint256 public _maxTxAmount = maxSupply / 1200; // 40_000
  uint256 public _maxAccountAmount = maxSupply / 400; // 120_000
  
  uint256 public totalBurned;

  // Fees
  uint256 public feeAdministrationWallet = 400; // 4%
  uint256 public feeDevWallet = 600; // 6%

  uint256 public feePool = 100; // 2%

  bool internal pausedStake = false;

  // special wallet permissions
  mapping (address => bool) public exemptOperatePausedToken;
  mapping (address => bool) public exemptFee;
  mapping (address => bool) public exemptFeeReceiver;
  mapping (address => bool) public exemptTxLimit;
  mapping (address => bool) public exemptAmountLimit;
  mapping (address => bool) public exemptStaker;

  // trading pairs
  address public liquidityPool;

  address public administrationWallet;

  address public devWallet;

  SwapHelper private swapHelper;

  address WBNB_BUSD_PAIR = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
  address WBNB_BBL_PAIR;

  bool private _noReentrancy = false;
  bool internal pausedToken = false;

  function getOwner() external view returns (address) { return owner(); }

  function enableToken() external isAuthorized(0) { pausedToken = false; }

  function getFeeTotal() public view returns(uint256) { return feePool + feeAdministrationWallet + feeDevWallet; }

  function togglePauseStake(bool pauseState) external isAuthorized(0) { pausedStake = pauseState; }

  function getSwapHelperAddress() external view returns (address) { return address(swapHelper); }

  function setFeesPool(uint256 pool) external isAuthorized(1) {
    require(pool + feeAdministrationWallet + feeDevWallet < 1500, "Maximum total fee is fixed on 15%");
    feePool = pool;
  }

  function setFeesDirectWallet(uint256 administration) external isAuthorized(1) {
    require(feePool + administration + feeDevWallet < 1500, "Maximum total fee is fixed on 15%");
    feeAdministrationWallet = administration;
  }

  function setFeeDevWallet(uint256 devFee) external isAuthorized(1) {
    require(feePool + feeAdministrationWallet + devFee < 1500, "Maximum total fee is fixed on 15%");
    feeDevWallet = devFee;
  }

  function setDevWallet(address wallet) public isAuthorized(0) {
    devWallet = wallet;
  }

  function setMaxTxAmountWithDecimals(uint256 decimalAmount) public isAuthorized(1) {
    require(decimalAmount <= maxSupply, "Amount is bigger then maximum supply token");
    _maxTxAmount = decimalAmount;
  }

  function setMaxTxAmount(uint256 amount) external isAuthorized(1) { setMaxTxAmountWithDecimals(amount * (10 ** decimal)); }

  function setMaxAccountAmountWithDecimals(uint256 decimalAmount) public isAuthorized(1) {
    require(decimalAmount <= maxSupply, "Amount is bigger then maximum supply token");
    _maxAccountAmount = decimalAmount;
  }

  function setMaxAccountAmount(uint256 amount) external isAuthorized(1) { setMaxAccountAmountWithDecimals(amount * (10 ** decimal)); }

  // Excempt Controllers
  function setExemptOperatePausedToken(address account, bool operation) public isAuthorized(0) {exemptOperatePausedToken[account] = operation; }
  function setExemptFee(address account, bool operation) public isAuthorized(2) { exemptFee[account] = operation; }
  function setExemptFeeReceiver(address account, bool operation) public isAuthorized(2) { exemptFeeReceiver[account] = operation; }
  function setExemptTxLimit(address account, bool operation) public isAuthorized(2) { exemptTxLimit[account] = operation; }
  function setExemptAmountLimit(address account, bool operation) public isAuthorized(2) { exemptAmountLimit[account] = operation; }
  function setExemptStaker(address account, bool operation) public isAuthorized(2) { exemptStaker[account] = operation; }

  // Special Wallets
  function setAdministrationWallet(address account) public isAuthorized(0) { administrationWallet = account; }
  
  receive() external payable { }

  constructor()ERC20(_name, _symbol) {
    PancakeRouter router = PancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    WBNB_BBL_PAIR = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));
    liquidityPool = WBNB_BBL_PAIR;

    // Liquidity pair
    exemptAmountLimit[WBNB_BBL_PAIR] = true;
    exemptTxLimit[WBNB_BBL_PAIR] = true;
    exemptStaker[WBNB_BBL_PAIR] = true;
    
    // Token address
    exemptFee[address(this)] = true;
    exemptTxLimit[address(this)] = true;
    exemptAmountLimit[address(this)] = true;
    exemptStaker[address(this)] = true;

    // DEAD Waller
    exemptTxLimit[DEAD] = true;
    exemptAmountLimit[DEAD] = true;
    exemptStaker[DEAD] = true;
    exemptFee[DEAD] = true;

    // Zero Waller
    exemptTxLimit[ZERO] = true;
    exemptAmountLimit[ZERO] = true;
    exemptStaker[ZERO] = true;

    //Owner wallet
    address ownerWallet = _msgSender();
    exemptFee[ownerWallet] = true;
    exemptTxLimit[ownerWallet] = true;
    exemptAmountLimit[ownerWallet] = true;
    exemptStaker[ownerWallet] = true;
    exemptOperatePausedToken[ownerWallet] = true;

    devWallet = 0xAFbA5af54B9D0914b7B7709C46FdF13Fe5937E4E;
    administrationWallet = 0xc4c7e6Ba1b4627f943e05f8C771a5786CDd3aeFe;

    exemptFee[administrationWallet] = true;
    exemptTxLimit[administrationWallet] = true;
    exemptAmountLimit[administrationWallet] = true;

    swapHelper = new SwapHelper();
    swapHelper.safeApprove(WBNB, address(this), type(uint256).max);

    _mint(ownerWallet, maxSupply);

    feeAdministrationWallet = 9100;
    pausedToken = true;
  }

  function burn(uint256 amount) external {
    _burn(_msgSender(), amount);
    totalBurned += amount;
  }

  function decimals() public view override returns (uint8) { 
    return decimal;
  }

  function _beforeTokenTransfer( address from, address, uint256 amount ) internal view override {
    require(amount <= _maxTxAmount || exemptTxLimit[from], "Excedded the maximum transaction limit");
    require(!pausedToken || exemptOperatePausedToken[from], "Token is paused");
  }

  function _afterTokenTransfer( address, address to, uint256 ) internal view override {
    require(_balances[to] <= _maxAccountAmount || exemptAmountLimit[to], "Excedded the maximum tokens that an wallet can hold");
  }

  function _transfer( address sender, address recipient,uint256 amount ) internal override {
    require(!_noReentrancy, "ReentrancyGuard: reentrant call happens");
    _noReentrancy = true;
    
    require(sender != address(0) && recipient != address(0), "transfer from the zero address");
    
    _beforeTokenTransfer(sender, recipient, amount);

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "transfer amount exceeds your balance");
    uint256 newSenderBalance = senderBalance - amount;
    _balances[sender] = newSenderBalance;

    uint256 feeAmount = 0;
    if (!exemptFee[sender] && !exemptFeeReceiver[recipient]) feeAmount = (getFeeTotal() * amount) / 10000;

    exchangeFeeParts(feeAmount);
    uint256 newRecipentAmount = _balances[recipient] + (amount - feeAmount);
    _balances[recipient] = newRecipentAmount;

    _afterTokenTransfer(sender, recipient, amount);

    _noReentrancy = false;
    emit Transfer(sender, recipient, amount);
  }

  function exchangeFeeParts(uint256 incomingFeeTokenAmount) private returns (bool){
    if (incomingFeeTokenAmount == 0) return false;
    _balances[address(this)] += incomingFeeTokenAmount;
    
    address pairWbnbBbl = WBNB_BBL_PAIR;
    if (_msgSender() == pairWbnbBbl || pausedStake) return false;
    uint256 feeTokenAmount = _balances[address(this)];
    _balances[address(this)] = 0;

    // Gas optimization
    address wbnbAddress = WBNB;
    (uint112 reserve0, uint112 reserve1) = getTokenReserves(pairWbnbBbl);
    bool reversed = isReversed(pairWbnbBbl, wbnbAddress);
    if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }
    _balances[pairWbnbBbl] += feeTokenAmount;
    address swapHelperAddress = address(swapHelper);
    uint256 wbnbBalanceBefore = getTokenBalanceOf(wbnbAddress, swapHelperAddress);
    
    uint256 wbnbAmount = getAmountOut(feeTokenAmount, reserve1, reserve0);
    swapToken(pairWbnbBbl, reversed ? 0 : wbnbAmount, reversed ? wbnbAmount : 0, swapHelperAddress);
    uint256 wbnbBalanceNew = getTokenBalanceOf(wbnbAddress, swapHelperAddress);  
    require(wbnbBalanceNew == wbnbBalanceBefore + wbnbAmount, "Wrong amount of swapped on WBNB");
    // Deep Stack problem avoid
    {
      // Gas optimization
      address busdAddress = BUSD;
      address pairWbnbBusd = WBNB_BUSD_PAIR;
      (reserve0, reserve1) = getTokenReserves(pairWbnbBusd);
      reversed = isReversed(pairWbnbBusd, wbnbAddress);
      if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }

      uint256 busdBalanceBefore = getTokenBalanceOf(busdAddress, address(this));
      tokenTransferFrom(wbnbAddress, swapHelperAddress, pairWbnbBusd, wbnbAmount);
      uint256 busdAmount = getAmountOut(wbnbAmount, reserve0, reserve1);
      swapToken(pairWbnbBusd, reversed ? busdAmount : 0, reversed ? 0 : busdAmount, address(this));
      uint256 busdBalanceNew = getTokenBalanceOf(busdAddress, address(this));
      require(busdBalanceNew == busdBalanceBefore + busdAmount, "Wrong amount swapped on BUSD");
      if (feeAdministrationWallet > 0) tokenTransfer(busdAddress, administrationWallet, (busdAmount * feeAdministrationWallet) / getFeeTotal());
      if (feeDevWallet > 0) tokenTransfer(busdAddress, devWallet, (busdAmount * feeDevWallet) / getFeeTotal());
    }
    return true;
  }

  function buyBackAndHold(uint256 amount, address receiver) external isAuthorized(3) { buyBackAndHoldWithDecimals(amount * (10 ** decimalBUSD), receiver); }

  function buyBackAndHoldWithDecimals(uint256 decimalAmount, address receiver) public isAuthorized(3) { buyBackWithDecimals(decimalAmount, receiver); }

  function buyBackAndBurn(uint256 amount) external isAuthorized(3) { buyBackAndBurnWithDecimals(amount * (10 ** decimalBUSD)); }

  function buyBackAndBurnWithDecimals(uint256 decimalAmount) public isAuthorized(3) { buyBackWithDecimals(decimalAmount, address(0)); }

  function buyBackWithDecimals(uint256 decimalAmount, address destAddress) private {
    uint256 maxBalance = getTokenBalanceOf(BUSD, address(this));
    if (maxBalance < decimalAmount) revert(string(abi.encodePacked("insufficient BUSD amount[", Strings.toString(decimalAmount), "] on contract[", Strings.toString(maxBalance), "]")));

    (uint112 reserve0,uint112 reserve1) = getTokenReserves(WBNB_BUSD_PAIR);
    bool reversed = isReversed(WBNB_BUSD_PAIR, BUSD);
    if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }

    tokenTransfer(BUSD, WBNB_BUSD_PAIR, decimalAmount);
    uint256 wbnbAmount = getAmountOut(decimalAmount, reserve0, reserve1);
    swapToken(WBNB_BUSD_PAIR, reversed ? wbnbAmount : 0, reversed ? 0 : wbnbAmount, address(this));

    bool previousExemptFeeState = exemptFee[WBNB_BBL_PAIR];
    exemptFee[WBNB_BBL_PAIR] = true;
    
    address pairWbnbBbl = WBNB_BBL_PAIR;
    address swapHelperAddress = address(swapHelper);
    (reserve0, reserve1) = getTokenReserves(pairWbnbBbl);
    reversed = isReversed(pairWbnbBbl, WBNB);
    if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }

    tokenTransfer(WBNB, pairWbnbBbl, wbnbAmount);
    
    uint256 bblAmount = getAmountOut(wbnbAmount, reserve0, reserve1);
    if (destAddress == address(0)) {
      swapToken(pairWbnbBbl, reversed ? bblAmount : 0, reversed ? 0 : bblAmount, swapHelperAddress);
      _burn(swapHelperAddress, bblAmount);
      totalBurned += bblAmount;
    } else {
      swapToken(pairWbnbBbl, reversed ? bblAmount : 0, reversed ? 0 : bblAmount, destAddress);
    }
    exemptFee[WBNB_BBL_PAIR] = previousExemptFeeState;
  }
 
  function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, 'Insufficient amount in');
    require(reserveIn > 0 && reserveOut > 0, 'Insufficient liquidity');
    uint256 amountInWithFee = amountIn * 9975;
    uint256 numerator = amountInWithFee  * reserveOut;
    uint256 denominator = (reserveIn * 10000) + amountInWithFee;
    amountOut = numerator / denominator;
  }

  // gas optimization on get Token0 from a pair liquidity pool
  function isReversed(address pair, address tokenA) internal view returns (bool) {
    address token0;
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x0dfe168100000000000000000000000000000000000000000000000000000000)
      failed := iszero(staticcall(gas(), pair, emptyPointer, 0x04, emptyPointer, 0x20))
      token0 := mload(emptyPointer)
    }
    if (failed) revert(string(abi.encodePacked("Unable to check direction of token ", Strings.toHexString(uint160(tokenA), 20) ," from pair ", Strings.toHexString(uint160(pair), 20))));
    return token0 != tokenA;
  }

  // gas optimization on transfer token
  function tokenTransfer(address token, address recipient, uint256 amount) internal {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(emptyPointer, 0x04), recipient)
      mstore(add(emptyPointer, 0x24), amount)
      failed := iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0))
    }
    if (failed) revert(string(abi.encodePacked("Unable to transfer ", Strings.toString(amount), " of token [", Strings.toHexString(uint160(token), 20) ,"] to address ", Strings.toHexString(uint160(recipient), 20))));
  }

  // gas optimization on transfer from token method
  function tokenTransferFrom(address token, address from, address recipient, uint256 amount) internal {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
      mstore(add(emptyPointer, 0x04), from)
      mstore(add(emptyPointer, 0x24), recipient)
      mstore(add(emptyPointer, 0x44), amount)
      failed := iszero(call(gas(), token, 0, emptyPointer, 0x64, 0, 0)) 
    }
    if (failed) revert(string(abi.encodePacked("Unable to transfer from [", Strings.toHexString(uint160(from), 20)  ,"] ", Strings.toString(amount), " of token [", Strings.toHexString(uint160(token), 20) ,"] to address ", Strings.toHexString(uint160(recipient), 20))));
  }

  // gas optimization on swap operation using a liquidity pool
  function swapToken(address pair, uint amount0Out, uint amount1Out, address receiver) internal {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)
      mstore(add(emptyPointer, 0x04), amount0Out)
      mstore(add(emptyPointer, 0x24), amount1Out)
      mstore(add(emptyPointer, 0x44), receiver)
      mstore(add(emptyPointer, 0x64), 0x80)
      mstore(add(emptyPointer, 0x84), 0)
      failed := iszero(call(gas(), pair, 0, emptyPointer, 0xa4, 0, 0))
    }
    if (failed) revert(string(abi.encodePacked("Unable to swap ", Strings.toString(amount0Out == 0 ? amount1Out : amount0Out), " on Pain [", Strings.toHexString(uint160(pair), 20)  ,"] to receiver ", Strings.toHexString(uint160(receiver), 20) )));
  }

  // gas optimization on get balanceOf fron BEP20 or ERC20 token
  function getTokenBalanceOf(address token, address holder) internal view returns (uint112 tokenBalance) {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x70a0823100000000000000000000000000000000000000000000000000000000)
      mstore(add(emptyPointer, 0x04), holder)
      failed := iszero(staticcall(gas(), token, emptyPointer, 0x24, emptyPointer, 0x40))
      tokenBalance := mload(emptyPointer)
    }
    if (failed) revert(string(abi.encodePacked("Unable to get balance from wallet [", Strings.toHexString(uint160(holder), 20) ,"] of token [", Strings.toHexString(uint160(token), 20) ,"] ")));
  }

  // gas optimization on get reserves from liquidity pool
  function getTokenReserves(address pairAddress) internal view returns (uint112 reserve0, uint112 reserve1) {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
      failed := iszero(staticcall(gas(), pairAddress, emptyPointer, 0x4, emptyPointer, 0x40))
      reserve0 := mload(emptyPointer)
      reserve1 := mload(add(emptyPointer, 0x20))
    }
    if (failed) revert(string(abi.encodePacked("Unable to get reserves from pair [", Strings.toHexString(uint160(pairAddress), 20), "]")));
  }

  function walletHolder(address account) private view returns (address holder) {
    return exemptStaker[account] ? address(0x00) : account;
  }

  function setWBNB_BBL_PAIR(address newPair) external isAuthorized(0) { WBNB_BBL_PAIR = newPair; }
  function setWBNB_BUSD_Pair(address newPair) external isAuthorized(0) { WBNB_BUSD_PAIR = newPair; }
  function getWBNB_BBL_PAIR() external view returns(address) { return WBNB_BBL_PAIR; }
  function getWBNB_BUSD_Pair() external view returns(address) { return WBNB_BUSD_PAIR; }

}
