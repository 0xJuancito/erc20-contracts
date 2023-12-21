// SPDX-License-Identifier: PROPRIETARY - Crypto Lamen

pragma solidity 0.8.13;

import "./ERC20.sol";

import "./IPancake.sol";
import "./GasHelper.sol";
import "./SwapHelper.sol";

contract EcoinToken is GasHelper, ERC20 {
  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ZERO = 0x0000000000000000000000000000000000000000;
  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC WBNB

  string constant _name = "Ecoin Finance";
  string constant _symbol = "ECOIN";

  string constant public url = "www.ecoin-finance.com";
  string constant public author = "Lameni";

  // Token Details
  uint8 constant decimal = 18;
  uint256 constant maxSupply = 1_000_000_000 * (10 ** decimal);

  // Wallets limits
  uint256 public _maxTxAmount = maxSupply / 1000; // 0.1%
  uint256 public _maxAccountAmount = maxSupply / 100; // 1%
  uint256 public _minAmountToAutoSwap =  100 * (10 ** decimal); // 100

  // Fees
  uint256 public feePool = 300; // 3%
  uint256 public feeStake = 200;  // 2%
  uint256 public feeBurnRate = 100; // 1%
  uint256 public feeAdministrationWallet = 200; // 2%
  uint256 public feeInternalFundWallet = 0; // 0%

  uint constant maxTotalFee = 1600;
  mapping(address => uint) public specialFeesByWallet;

  // Helpers
  bool internal pausedToken;
  bool private _noReentrancy;

  bool public pausedStake;
  bool public pausedSwapPool;
  bool public pausedSwapAdmin;
  bool public disabledStake;

  // Counters
  uint256 public totalBurned;
  uint256 public accumulatedToStake;
  uint256 public accumulatedToAdmin;
  uint256 public accumulatedToPool;

  // Liquidity Pair
  address public liquidityPool;

  // Wallets
  address public administrationWallet;
  address public internalFundWallet;

  address public swapHelperAddress;

  // Restricted Wallets
  address[] public devsWallet = new address[](5);

  mapping(address => uint) public devLimitLastSell;
  mapping(address => uint) public devLimitAmountSell;
  mapping(address => uint) public devRestrictedDailySell;

  // STAKE VARIABLES
  mapping(address => HolderShare) public holderMap;
  uint256 public _holdersIndex;
  address[] public _holders;

  uint256 constant private stakePrecision = 10 ** 18;
  uint256 private stakePerShare;

  uint256 public minTokenHoldToStake = 100 * (10 ** decimal); // min holder must have to be able to receive stakes
  uint256 public minTokenToDistribute = 10 * (10 ** decimal); // min acumulated Tokens before execute a distribution
  uint256 public minTokenToReceive = 1 * (10 ** decimal); // min Token each user shoud acumulate of stake before receive it.

  uint256 public totalTokens;
  uint256 public totalTokensStaked;
  uint256 public totalTokensDistributed;
  uint256 public gasLimiter = 200_000;

  bool public emitStakeEvent;
  bool private initialized;

  struct HolderShare {
    uint256 amountToken;
    uint256 totalReceived;
    uint256 pendingReceive;
    uint256 entryPointMarkup;
    uint256 arrayIndex;
    uint256 receivedAt;
  }
  receive() external payable { }

  constructor()ERC20(_name, _symbol) {}

  function initialize() external onlyOwner {
    require(!initialized, "Contract already initialized");
    initialized = true;

    //Add permission
    permissions[0][_msgSender()] = true;
    permissions[1][_msgSender()] = true;
    permissions[2][_msgSender()] = true;
    permissions[3][_msgSender()] = true;
    
    //Initial params
    swapFee = 25;
    gasLimiter = 200_000;
    minTokenHoldToStake = 100 * (10 ** decimal); // min holder must have to be able to receive stakes
    minTokenToDistribute = 10 * (10 ** decimal); // min acumulated Tokens before execute a distribution
    minTokenToReceive = 1 * (10 ** decimal);
    devsWallet = new address[](5);

    _maxTxAmount = maxSupply / 1000; // 0.1%
    _maxAccountAmount = maxSupply / 100; // 1%
    _minAmountToAutoSwap =  100 * (10 ** decimal); // 100
    
    feePool = 300; // 3%
    feeStake = 200;  // 2%
    feeBurnRate = 100; // 1%
    feeAdministrationWallet = 200; // 2%
    feeInternalFundWallet = 0; // 0%

    //Setup contract
    PancakeRouter router = PancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); // BSC
    
    // Liquidity pair
    liquidityPool = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));

    administrationWallet = _msgSender();
    internalFundWallet = _msgSender();

    uint baseAttributes = 0;
    baseAttributes = setExemptAmountLimit(baseAttributes, true);
    baseAttributes = setExemptStaker(baseAttributes, true);
    _attributeMap[liquidityPool] = baseAttributes;

    baseAttributes = setExemptTxLimit(baseAttributes, true);
    _attributeMap[DEAD] = baseAttributes;
    _attributeMap[ZERO] = baseAttributes;

    baseAttributes = setExemptFee(baseAttributes, true);
    _attributeMap[address(this)] = baseAttributes;

    baseAttributes = setExemptOperatePausedToken(baseAttributes, true);
    baseAttributes = setExemptDistributionMaker(baseAttributes, true);
    _attributeMap[_msgSender()] = baseAttributes;

    SwapHelper swapHelper = new SwapHelper();
    swapHelper.safeApprove(WBNB, address(this), type(uint256).max);
    swapHelper.transferOwnership(_msgSender());
    swapHelperAddress = address(swapHelper);

    baseAttributes = setExemptOperatePausedToken(baseAttributes, false);
    _attributeMap[swapHelperAddress] = baseAttributes;

    _mint(_msgSender(), maxSupply);

    pausedToken = true;
  }

  // ----------------- Public Views -----------------
  function name() public pure override returns (string memory) { return _name; }
  function symbol() public pure override returns (string memory) { return _symbol; }
  function getOwner() external view returns (address) { return owner(); }
  function decimals() public pure override returns (uint8) { return decimal; }
  function getFeeTotal() public view returns(uint256) { return feePool + feeStake + feeBurnRate + feeAdministrationWallet + feeInternalFundWallet; }
  function getSpecialWalletFee(address target) public view returns(uint stake, uint pool, uint burnRate, uint adminFee, uint internalFundFee ) {
    uint composedValue = specialFeesByWallet[target];
    stake = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    pool = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    burnRate = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    adminFee = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    internalFundFee = composedValue % 1e4;
  }
  function getStakeHoldersSize() public view returns (uint) { return _holders.length; }

  // ----------------- Authorized Methods -----------------

  function enableToken() external isAuthorized(0) { pausedToken = false; }
  function setLiquidityPool(address newPair) external isAuthorized(0) { liquidityPool = newPair; }
  function setPausedStake(bool state) external isAuthorized(0) { pausedStake = state; }
  function setPausedSwapPool(bool state) external isAuthorized(0) { pausedSwapPool = state; }
  function setPausedSwapAdmin(bool state) external isAuthorized(0) { pausedSwapAdmin = state; }
  function setDisabledStake(bool state) external isAuthorized(0) { disabledStake = state; }
  function setEmitStakeEvent(bool state) external isAuthorized(0) { emitStakeEvent = state; }

  // ----------------- Wallets Settings -----------------
  function setAdministrationWallet(address account) public isAuthorized(0) { administrationWallet = account; }
  function setInternalFundWallet(address account) public isAuthorized(0) { internalFundWallet = account; }
  function setDevWallet(address account, uint pos) public isAuthorized(0) {
    uint dailySeconds = 86400;
    require(devLimitLastSell[devsWallet[pos]] + dailySeconds < block.timestamp, "Can't change dev wallet within 24h after execute a sell");
    devsWallet[pos] = account;
  }
  function setRestrictedDailySell(address dev, uint amount) public isAuthorized(0) { devRestrictedDailySell[dev] = amount; }

  // ----------------- Fee Settings -----------------
  function setFeesContract(uint256 stake, uint256 pool, uint256 burnRate) external isAuthorized(1) {
    feePool = pool;
    feeStake = stake;
    feeBurnRate = burnRate;
    require(getFeeTotal() <= maxTotalFee, "All rates and fee together must be lower than 16%");
  }
  function setFeesOperational(uint256 administration, uint256 feeInternalFund) external isAuthorized(1) {
    feeAdministrationWallet = administration;
    feeInternalFundWallet = feeInternalFund;
    require(getFeeTotal() <= maxTotalFee, "All rates and fee together must be lower than 16%");
  }

  function setSpecialWalletFee(address target, uint stake, uint pool, uint burnRate, uint adminFee, uint internalFundFee)  external isAuthorized(1) {
    uint total = stake + pool + burnRate + adminFee + internalFundFee;
    require(total <= maxTotalFee, "All rates and fee together must be lower than 16%");
    uint composedValue = stake + (pool * 1e4) + (burnRate * 1e8) + (adminFee * 1e12) + (internalFundFee * 1e16);
    specialFeesByWallet[target] = composedValue;
  }

  // ----------------- Token Flow Settings -----------------
  function setMaxTxAmount(uint256 maxTxAmount) public isAuthorized(1) {
    require(maxTxAmount >= maxSupply / 1000000, "Amount must be bigger then 0.0001% tokens"); // 1000 tokens
    _maxTxAmount = maxTxAmount;
  }
  function setMaxAccountAmount(uint256 maxAccountAmount) public isAuthorized(1) {
    require(maxAccountAmount >= maxSupply / 1000000, "Amount must be bigger then 0.0001% tokens"); // 1000 tokens
    _maxAccountAmount = maxAccountAmount;
  }
  function setMinAmountToAutoSwap(uint256 amount) public isAuthorized(1) {
    _minAmountToAutoSwap = amount;
  }

  // ----------------- Special Authorized Operations -----------------
  function buyBackAndHoldWithDecimals(uint256 decimalAmount, address receiver) public isAuthorized(3) { buyBackWithDecimals(decimalAmount, receiver); }
  function buyBackAndBurnWithDecimals(uint256 decimalAmount) public isAuthorized(3) { buyBackWithDecimals(decimalAmount, address(0)); }

  // ----------------- External Methods -----------------
  function burn(uint256 amount) external { _burn(_msgSender(), amount); }

  // ----------------- Internal CORE -----------------
  function _transfer( address sender, address receiver,uint256 amount) internal override {
    require(amount > 0, "Invalid Amount");
    require(!_noReentrancy, "ReentrancyGuard Alert");
    _noReentrancy = true;

    uint senderAttributes = _attributeMap[sender];
    uint receiverAttributes = _attributeMap[receiver];
    // Initial Checks
    require(sender != address(0) && receiver != address(0), "transfer from the zero address");
    require(!pausedToken || isExemptOperatePausedToken(senderAttributes), "Token is paused");
    require(amount <= _maxTxAmount || isExemptTxLimit(senderAttributes), "Excedded the maximum transaction limit");
    checkLimitOfResitrictedWallets(sender, receiver, amount);
    
    // Update Sender Balance to add pending staking 
    if(!isExemptStaker(senderAttributes)) _updateHolder(sender, _balances[sender], minTokenHoldToStake, stakePerShare, stakePrecision);
    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "Transfer amount exceeds your balance");
    uint256 newSenderBalance = senderBalance - amount;
    _balances[sender] = newSenderBalance;
    

    uint adminFee = feeAdministrationWallet;
    uint poolFee = feePool;
    uint burnFee = feeBurnRate;
    uint internalFundFee = feeInternalFundWallet;
    uint stakeFee = feeStake;

    // Calculate Fees
    uint256 feeAmount = 0;
    if(!isExemptFee(senderAttributes) && !isExemptFeeReceiver(receiverAttributes)) {
      if(!isExemptInnerTrade(senderAttributes) || !isExemptInnerTrade(receiverAttributes)) { // Special trade between defined wallets

        if(isSpecialFeeWallet(senderAttributes)) { // Check special wallet fee on sender
          (stakeFee, poolFee, burnFee, adminFee, internalFundFee) = getSpecialWalletFee(sender);
        } else if(isSpecialFeeWalletReceiver(receiverAttributes)) { // Check special wallet fee on receiver
          (stakeFee, poolFee, burnFee, adminFee, internalFundFee) = getSpecialWalletFee(receiver);
        }
        feeAmount = ((stakeFee + poolFee + burnFee + adminFee + internalFundFee) * amount) / 10000;
      }
    }

    if (feeAmount != 0) splitFee(feeAmount, sender, adminFee, poolFee, burnFee, internalFundFee, stakeFee);
    if ((!pausedSwapPool || !pausedSwapAdmin) && !isExemptDistributionMaker(senderAttributes)) autoSwap(sender, poolFee, adminFee);
    
    // Update Recipent Balance
    uint256 newRecipentBalance = _balances[receiver] + (amount - feeAmount);
    _balances[receiver] = newRecipentBalance;
    require(newRecipentBalance <= _maxAccountAmount || isExemptAmountLimit(receiverAttributes), "Excedded the maximum tokens an wallet can hold");

    if (!disabledStake) executeStakeOperations(sender, receiver, newSenderBalance, newRecipentBalance, senderAttributes, receiverAttributes);

    _noReentrancy = false;
    emit Transfer(sender, receiver, amount - feeAmount);
  }

  function autoSwap(address sender, uint poolFee, uint adminFee) private {
    // --------------------- Execute Auto Swap -------------------------
    address liquidityPair = liquidityPool;
    if (sender == liquidityPair) return;

    uint poolAmount = accumulatedToPool;
    uint adminAmount = accumulatedToAdmin;
    uint totalAmount = poolAmount + adminAmount;
    if (totalAmount < _minAmountToAutoSwap) return;

    // Execute auto swap
    address wbnbAddress = WBNB;
    address swapHelper = swapHelperAddress;

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, wbnbAddress);
    if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }
    _balances[liquidityPair] += totalAmount;

    uint256 wbnbBalanceBefore = getTokenBalanceOf(wbnbAddress, swapHelper);
    uint256 wbnbAmount = getAmountOut(totalAmount, reserve1, reserve0);
    swapToken(liquidityPair, reversed ? 0 : wbnbAmount, reversed ? wbnbAmount : 0, swapHelper);
    uint256 wbnbBalanceNew = getTokenBalanceOf(wbnbAddress, swapHelper);  
    require(wbnbBalanceNew == wbnbBalanceBefore + wbnbAmount, "Wrong amount of swapped on WBNB");

    // --------------------- Transfer Swapped Amount -------------------------
    if (poolAmount > 0 && poolFee > 0) { // Cost 2 cents
      uint amountToSend = (wbnbBalanceNew * poolFee) / (poolFee + adminFee);
      tokenTransferFrom(wbnbAddress, swapHelper, address(this), amountToSend);
    }
    if (adminAmount > 0 && adminFee > 0) { // Cost 2 cents
      uint amountToSend = (wbnbBalanceNew * adminFee) / (poolFee + adminFee);
      tokenTransferFrom(wbnbAddress, swapHelper, administrationWallet, amountToSend);
    }

    accumulatedToPool = 0;
    accumulatedToAdmin = 0;
  }

  function splitFee(uint256 incomingFeeTokenAmount, address sender, uint adminFee, uint poolFee, uint burnFee, uint internalFundFee, uint stakeFee) private {
    uint256 totalFee = adminFee + poolFee + burnFee + internalFundFee + stakeFee;

    //Burn
    if (burnFee > 0) {
      uint256 burnAmount = (incomingFeeTokenAmount * burnFee) / totalFee;
      _balances[address(this)] += burnAmount;
      _burn(address(this), burnAmount);
    }

    if (stakeFee > 0) { accumulatedToStake += (incomingFeeTokenAmount * stakeFee) / totalFee; }

    // Administrative distribution
    if (adminFee > 0) { 
      accumulatedToAdmin += (incomingFeeTokenAmount * adminFee) / totalFee;
      if (pausedSwapAdmin) {
        address wallet = administrationWallet;
        uint256 walletBalance = _balances[wallet] + accumulatedToAdmin;
        _balances[wallet] = walletBalance;
        if(!isExemptStaker(_attributeMap[wallet])) _updateHolder(wallet, walletBalance, minTokenHoldToStake, stakePerShare, stakePrecision);
        emit Transfer(sender, wallet, accumulatedToAdmin);
        accumulatedToAdmin = 0;
      }
    }

    // Pool Distribution
    if (poolFee > 0) { 
      accumulatedToPool += (incomingFeeTokenAmount * poolFee) / totalFee;
      if (pausedSwapPool) {
        _balances[address(this)] += accumulatedToPool;
        emit Transfer(sender, address(this), accumulatedToPool);
        accumulatedToPool = 0;
      }
    }

    // InternalFund distribution
    if (internalFundFee > 0) {
      uint feeAmount = (incomingFeeTokenAmount * internalFundFee) / totalFee;
      address wallet = internalFundWallet;
      uint256 walletBalance = _balances[wallet] + feeAmount;
      _balances[wallet] = walletBalance;
      if(!isExemptStaker(_attributeMap[wallet])) _updateHolder(wallet, walletBalance, minTokenHoldToStake, stakePerShare, stakePrecision);
      emit Transfer(sender, wallet, feeAmount);
    }
  }

  function checkLimitOfResitrictedWallets(address sender, address receiver, uint amount) private {
    address dev = address(0);
    for(uint i=0; i<5; i++) {
      address currentDev = devsWallet[i];
      if (receiver == currentDev || sender == currentDev) {
        dev = currentDev;
        break;
      }
    }
    if (dev == address(0)) return;

    uint lastSell = devLimitLastSell[dev];
    uint amounSell = devLimitAmountSell[dev];
    uint amounLimit = devRestrictedDailySell[dev];
    uint dailySeconds = 86400;
    if (lastSell + dailySeconds < block.timestamp) {
      // last sell has more than 24h... so reset its limit.
      amounSell = 0;
      lastSell = block.timestamp;
    }
    amounSell += amount;
    require(amounLimit == 0 || amounSell <= amounLimit, "Dev wallet has reached its daily sell limit");

    devLimitLastSell[dev] = lastSell;
    devLimitAmountSell[dev] = amounSell;
  }

  function balanceOf(address account) public view override returns (uint256) { 
    uint256 entryPointMarkup = holderMap[account].entryPointMarkup;
    uint256 totalToBePaid = (holderMap[account].amountToken * stakePerShare) / stakePrecision;
    uint256 pending = holderMap[account].pendingReceive + (totalToBePaid <= entryPointMarkup ? 0 : totalToBePaid - entryPointMarkup);
    return _balances[account] + pending;
  }

  function _burn(address account, uint256 amount) internal override {
    require(account != address(0), "ERC20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
      _balances[DEAD] += amount;
      totalBurned += amount;
    }
    emit Transfer(account, DEAD, amount);
  }

  // --------------------- Stake Internal Methods -------------------------

  function setMinTokenHoldToStake(uint amount) external isAuthorized(1) { minTokenHoldToStake = amount; }

  function executeStakeOperations(address sender, address receiver, uint senderAmount, uint receiverAmount, uint senderAttributes, uint receiverAttributes) private {
    uint minTokenHolder = minTokenHoldToStake;
    uint stakePerShareValue = stakePerShare;
    uint stakePrecisionValue = stakePrecision;

    if(!isExemptStaker(senderAttributes)) _updateHolder(sender, senderAmount, minTokenHolder, stakePerShareValue, stakePrecisionValue);

    // Calculate new stake per share value
    uint accumulated = accumulatedToStake;
    if (accumulated > 0) {
      uint consideratedTotalTokens = totalTokens;
      stakePerShareValue += (accumulated * stakePrecisionValue) / (consideratedTotalTokens == 0 ? 1 : consideratedTotalTokens);
      stakePerShare = stakePerShareValue;
      totalTokensStaked += accumulated;
      accumulatedToStake = 0;
    }

    if(!isExemptStaker(receiverAttributes)) _updateHolder(receiver, receiverAmount, minTokenHolder, stakePerShareValue, stakePrecisionValue);
  }

  function _updateHolder(address holder, uint256 amount, uint minTokenHolder, uint stakePerShareValue, uint stakePrecisionValue) private {
    // If holder has less than minTokenHoldToStake, then does not participate on staking
    uint256 consideratedAmount = minTokenHolder <= amount ? amount : 0;
    uint256 holderAmount = holderMap[holder].amountToken;
    
    if (holderAmount > 0) {
      uint256 pendingToReceive = calculateDistribution(holder, holderAmount, stakePerShareValue, stakePrecisionValue);
      if (pendingToReceive > 0) {
        _balances[holder] += pendingToReceive;
        holderMap[holder].totalReceived += pendingToReceive;
        holderMap[holder].pendingReceive = 0;
        totalTokensDistributed += pendingToReceive;

        if(emitStakeEvent == true) emit Transfer(address(this), holder, pendingToReceive);
      }
    }

    if (consideratedAmount > 0 && holderAmount == 0 ) {
      addToHoldersList(holder);
    } else if (consideratedAmount == 0 && holderAmount > 0) {
      removeFromHoldersList(holder);
    }
    totalTokens = (totalTokens - holderAmount) + consideratedAmount;
    holderMap[holder].amountToken = consideratedAmount;
    holderMap[holder].entryPointMarkup = (consideratedAmount * stakePerShareValue) / stakePrecisionValue;
  }

  function addToHoldersList(address holder) private {
    holderMap[holder].arrayIndex = _holders.length;
    _holders.push(holder);
  }

  function removeFromHoldersList(address holder) private {
    address lastHolder = _holders[_holders.length - 1];
    uint256 holderIndexRemoved = holderMap[holder].arrayIndex;
    _holders[holderIndexRemoved] = lastHolder;
    _holders.pop();
    holderMap[lastHolder].arrayIndex = holderIndexRemoved;
    holderMap[holder].arrayIndex = 0;
  }

  function calculateDistribution(address holder, uint amountToken, uint stakePerShareValue, uint stakePrecisionValue) private returns (uint) {
    uint256 entryPointMarkup = holderMap[holder].entryPointMarkup;
    uint256 totalToBePaid = (amountToken * stakePerShareValue) / stakePrecisionValue;

    if (totalToBePaid <= entryPointMarkup) return holderMap[holder].pendingReceive;
    uint256 newPendingAmount = holderMap[holder].pendingReceive + (totalToBePaid - entryPointMarkup);
    holderMap[holder].pendingReceive = newPendingAmount;
    holderMap[holder].entryPointMarkup = totalToBePaid;
    return newPendingAmount;
  }

  // --------------------- Private Methods -------------------------

  function buyBackWithDecimals(uint256 decimalAmount, address destAddress) private {
    uint256 maxBalance = getTokenBalanceOf(WBNB, address(this));
    if (maxBalance < decimalAmount) revert("insufficient WBNB amount on contract");

    address liquidityPair = liquidityPool;
    uint liquidityAttribute = _attributeMap[liquidityPair];

    uint newAttributes = setExemptTxLimit(liquidityAttribute, true);
    newAttributes = setExemptFee(liquidityAttribute, true);
    _attributeMap[liquidityPair] = newAttributes;

    address helperAddress = swapHelperAddress;

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, WBNB);
    if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }

    tokenTransfer(WBNB, liquidityPair, decimalAmount);
    
    uint256 tokenAmount = getAmountOut(decimalAmount, reserve0, reserve1);
    if (destAddress == address(0)) {
      swapToken(liquidityPair, reversed ? tokenAmount : 0, reversed ? 0 : tokenAmount, helperAddress);
      _burn(helperAddress, tokenAmount);
    } else {
      swapToken(liquidityPair, reversed ? tokenAmount : 0, reversed ? 0 : tokenAmount, destAddress);
    }
    _attributeMap[liquidityPair] = liquidityAttribute;
  }

}