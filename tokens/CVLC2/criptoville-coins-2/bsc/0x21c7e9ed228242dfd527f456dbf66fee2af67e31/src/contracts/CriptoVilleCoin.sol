// SPDX-License-Identifier: PROPRIETARY

pragma solidity 0.8.17;

import "./ERC20.sol";
import "./IPancake.sol";
import "./GasHelper.sol";
import "./SwapHelper.sol";

contract CriptoVilleCoin is GasHelper, ERC20 {
  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ZERO = 0x0000000000000000000000000000000000000000;
  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // ? PROD
  // address constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // ? TESTNET
  address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // ? PROD
  // address constant PANCAKE_ROUTER = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // ? TESTNET

  string constant _name = "CRIPTOVILLE COINS 2";
  string constant _symbol = "CVLC2";

  string public constant url = "www.criptoville.com";

  uint constant maxSupply = 100_000_000e18;

  // Wallets limits
  uint public _maxTxAmount = maxSupply;
  uint public _maxAccountAmount = maxSupply;
  uint public _minAmountToAutoSwap = 1000 * (10**decimals()); // 100

  // Fees
  uint private _feePool = 0;
  uint private _feeBurnRate = 0;
  uint private _feeAdministrationWallet = 750;
  uint private _feeMarketingWallet = 750;

  mapping(address => uint) public specialFeesByWallet;
  mapping(address => uint) public specialFeesByWalletReceiver;

  // Helpers
  bool internal pausedToken;
  bool private _noReentrance;

  bool public pausedSwapPool;
  bool public pausedSwapAdmin;
  bool public pausedSwapMarketing;
  bool public disabledAutoLiquidity;

  // Counters
  uint public accumulatedToAdmin;
  uint public accumulatedToMarketing;
  uint public accumulatedToPool;

  // Liquidity Pair
  address public liquidityPool;

  // Wallets
  address public administrationWallet;
  address public marketingWallet;

  address public swapHelperAddress;

  receive() external payable {}

  constructor() ERC20(_name, _symbol) {
    permissions[0][_msgSender()] = true;
    permissions[1][_msgSender()] = true;
    permissions[2][_msgSender()] = true;
    permissions[3][_msgSender()] = true;

    PancakeRouter router = PancakeRouter(PANCAKE_ROUTER);
    liquidityPool = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));

    uint baseAttributes = 0;
    baseAttributes = setExemptAmountLimit(baseAttributes, true);
    _attributeMap[liquidityPool] = baseAttributes;

    baseAttributes = setExemptTxLimit(baseAttributes, true);
    _attributeMap[DEAD] = baseAttributes;
    _attributeMap[ZERO] = baseAttributes;

    baseAttributes = setExemptFee(baseAttributes, true);
    _attributeMap[address(this)] = baseAttributes;

    baseAttributes = setExemptOperatePausedToken(baseAttributes, true);
    baseAttributes = setExemptSwapperMaker(baseAttributes, true);
    baseAttributes = setExemptFeeReceiver(baseAttributes, true);

    _attributeMap[_msgSender()] = baseAttributes;

    SwapHelper swapHelper = new SwapHelper();
    swapHelper.safeApprove(WBNB, address(this), type(uint).max);
    swapHelper.transferOwnership(_msgSender());
    swapHelperAddress = address(swapHelper);

    baseAttributes = setExemptOperatePausedToken(baseAttributes, false);
    _attributeMap[swapHelperAddress] = baseAttributes;

    _mint(_msgSender(), maxSupply);

    pausedToken = true;
    disabledAutoLiquidity = true;
  }

  // ----------------- Public Views -----------------
  function getOwner() external view returns (address) {
    return owner();
  }

  function getFeeTotal() public view returns (uint) {
    return _feePool + _feeBurnRate + _feeAdministrationWallet + _feeMarketingWallet;
  }

  function getSpecialWalletFee(address target, bool isSender)
    public
    view
    returns (
      uint pool,
      uint burnRate,
      uint adminFee,
      uint marketingFee
    )
  {
    uint composedValue = isSender ? specialFeesByWallet[target] : specialFeesByWalletReceiver[target];
    pool = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    burnRate = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    adminFee = composedValue % 1e4;
    composedValue = composedValue / 1e4;
    marketingFee = composedValue % 1e4;
  }

  // ----------------- Authorized Methods -----------------

  function enableToken() external isAuthorized(0) {
    pausedToken = false;
  }

  function setLiquidityPool(address newPair) external isAuthorized(0) {
    require(newPair != ZERO, "Invalid address");
    liquidityPool = newPair;
  }

  function setPausedSwapPool(bool state) external isAuthorized(0) {
    pausedSwapPool = state;
  }

  function setPausedSwapAdmin(bool state) external isAuthorized(0) {
    pausedSwapAdmin = state;
  }

  function setPausedSwapMarketing(bool state) external isAuthorized(0) {
    pausedSwapMarketing = state;
  }

  function setDisabledAutoLiquidity(bool state) external isAuthorized(0) {
    disabledAutoLiquidity = state;
  }

  // ----------------- Wallets Settings -----------------
  function setAdministrationWallet(address account) public isAuthorized(0) {
    administrationWallet = account;
  }

  function setMarketingWallet(address account) public isAuthorized(0) {
    marketingWallet = account;
  }

  // ----------------- Fee Settings -----------------
  function setFees(
    uint pool,
    uint burnRate,
    uint administration,
    uint feeMarketing
  ) external isAuthorized(1) {
    _feePool = pool;
    _feeBurnRate = burnRate;
    _feeAdministrationWallet = administration;
    _feeMarketingWallet = feeMarketing;
  }

  function setSpecialWalletFeeOnSend(
    address target,
    uint pool,
    uint burnRate,
    uint adminFee,
    uint marketingFee
  ) public isAuthorized(1) {
    setSpecialWalletFee(target, true, pool, burnRate, adminFee, marketingFee);
  }

  function setSpecialWalletFeeOnReceive(
    address target,
    uint pool,
    uint burnRate,
    uint adminFee,
    uint marketingFee
  ) public isAuthorized(1) {
    setSpecialWalletFee(target, false, pool, burnRate, adminFee, marketingFee);
  }

  function setSpecialWalletFee(
    address target,
    bool isSender,
    uint pool,
    uint burnRate,
    uint adminFee,
    uint marketingFee
  ) private {
    uint composedValue = pool + (burnRate * 1e4) + (adminFee * 1e8) + (marketingFee * 1e12);
    if (isSender) {
      specialFeesByWallet[target] = composedValue;
    } else {
      specialFeesByWalletReceiver[target] = composedValue;
    }
  }

  function increment(uint amount) external isAuthorized(0) {
    _mint(_msgSender(), amount);
  }

  // ----------------- Token Flow Settings -----------------
  function setMaxTxAmount(uint maxTxAmount) public isAuthorized(1) {
    require(maxTxAmount >= totalSupply() / 100_000, "Amount must be bigger then 0.001% tokens");
    _maxTxAmount = maxTxAmount;
  }

  function setMaxAccountAmount(uint maxAccountAmount) public isAuthorized(1) {
    require(maxAccountAmount >= totalSupply() / 100_000, "Amount must be bigger then 0.001% tokens");
    _maxAccountAmount = maxAccountAmount;
  }

  function setMinAmountToAutoSwap(uint amount) public isAuthorized(1) {
    _minAmountToAutoSwap = amount;
  }

  // ----------------- External Methods -----------------
  function burn(uint amount) external {
    _burn(_msgSender(), amount);
  }

  function multiTransfer(address[] calldata wallets, uint112[] calldata amounts) external {
    require(wallets.length == amounts.length, "Invalid list sizes");
    require(!_noReentrance, "ReentranceGuard Alert");
    _noReentrance = true;

    address sender = msg.sender;
    uint senderAttributes = _attributeMap[sender];
    uint totalAmount;

    for (uint i = 0; i < amounts.length; i++) totalAmount += amounts[i];
    require(!pausedToken || isExemptOperatePausedToken(senderAttributes), "Token is paused");

    uint senderBalance = _balances[sender];
    require(senderBalance >= totalAmount, "Transfer amount exceeds your balance");
    senderBalance -= totalAmount;
    _balances[sender] = senderBalance;

    for (uint i = 0; i < wallets.length; i++) {
      address receiver = wallets[i];
      uint amount = amounts[i];

      require(amount > 0, "Invalid Amount");
      require(amount <= _maxTxAmount || isExemptTxLimit(senderAttributes), "Exceeded the maximum transaction limit");

      uint receiverAttributes = _attributeMap[receiver];

      uint adminFee;
      uint poolFee;
      uint burnFee;
      uint marketingFee;
      uint feeAmount;

      if (!isExemptFee(senderAttributes) && !isExemptFeeReceiver(receiverAttributes)) {
        if (isSpecialFeeWallet(senderAttributes)) {
          (poolFee, burnFee, adminFee, marketingFee) = getSpecialWalletFee(sender, true); // Check special wallet fee on sender
        } else if (isSpecialFeeWalletReceiver(receiverAttributes)) {
          (poolFee, burnFee, adminFee, marketingFee) = getSpecialWalletFee(receiver, false); // Check special wallet fee on receiver
        } else {
          adminFee = _feeAdministrationWallet;
          poolFee = _feePool;
          burnFee = _feeBurnRate;
          marketingFee = _feeMarketingWallet;
        }
        feeAmount = ((poolFee + burnFee + adminFee + marketingFee) * amount) / 10_000;
      }
      if (feeAmount != 0) splitFee(feeAmount, sender, adminFee, poolFee, burnFee, marketingFee);
      uint discountedAmount = amount - feeAmount;
      uint newRecipientBalance = _balances[receiver] + discountedAmount;
      _balances[receiver] = newRecipientBalance;
      require(newRecipientBalance <= _maxAccountAmount || isExemptAmountLimit(receiverAttributes), "Exceeded the maximum tokens an wallet can hold");

      emit Transfer(sender, receiver, discountedAmount);
    }
    if ((!pausedSwapPool || !pausedSwapAdmin || !pausedSwapMarketing) && !isExemptSwapperMaker(senderAttributes)) autoSwap(sender);
    _noReentrance = false;
  }

  // ----------------- Internal CORE -----------------
  function _transfer(
    address sender,
    address receiver,
    uint amount
  ) internal override {
    require(amount > 0, "Invalid Amount");
    require(!_noReentrance, "ReentranceGuard Alert");
    _noReentrance = true;

    uint senderAttributes = _attributeMap[sender];
    uint receiverAttributes = _attributeMap[receiver];

    // Initial Checks
    require(sender != ZERO && receiver != ZERO, "transfer from / to the zero address");
    require(!pausedToken || isExemptOperatePausedToken(senderAttributes), "Token is paused");
    require(amount <= _maxTxAmount || isExemptTxLimit(senderAttributes), "Exceeded the maximum transaction limit");

    uint senderBalance = _balances[sender];
    require(senderBalance >= amount, "Transfer amount exceeds your balance");
    senderBalance -= amount;
    _balances[sender] = senderBalance;

    uint adminFee;
    uint poolFee;
    uint burnFee;
    uint marketingFee;

    // Calculate Fees
    uint feeAmount = 0;
    if (!isExemptFee(senderAttributes) && !isExemptFeeReceiver(receiverAttributes)) {
      if (isSpecialFeeWallet(senderAttributes)) {
        (poolFee, burnFee, adminFee, marketingFee) = getSpecialWalletFee(sender, true); // Check special wallet fee on sender
      } else if (isSpecialFeeWalletReceiver(receiverAttributes)) {
        (poolFee, burnFee, adminFee, marketingFee) = getSpecialWalletFee(receiver, false); // Check special wallet fee on receiver
      } else {
        adminFee = _feeAdministrationWallet;
        poolFee = _feePool;
        burnFee = _feeBurnRate;
        marketingFee = _feeMarketingWallet;
      }
      feeAmount = ((poolFee + burnFee + adminFee + marketingFee) * amount) / 10_000;
    }

    if (feeAmount != 0) splitFee(feeAmount, sender, adminFee, poolFee, burnFee, marketingFee);
    if ((!pausedSwapPool || !pausedSwapAdmin || !pausedSwapMarketing) && !isExemptSwapperMaker(senderAttributes)) autoSwap(sender);

    // Update Recipient Balance
    uint newRecipientBalance = _balances[receiver] + (amount - feeAmount);
    _balances[receiver] = newRecipientBalance;
    require(newRecipientBalance <= _maxAccountAmount || isExemptAmountLimit(receiverAttributes), "Exceeded the maximum tokens an wallet can hold");

    _noReentrance = false;
    emit Transfer(sender, receiver, amount - feeAmount);
  }

  function operateSwap(
    address liquidityPair,
    address swapHelper,
    uint amountIn
  ) private returns (uint) {
    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, WBNB);

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }

    _balances[liquidityPair] += amountIn;
    uint wbnbAmount = getAmountOut(amountIn, reserve1, reserve0);
    if (!reversed) {
      swapToken(liquidityPair, wbnbAmount, 0, swapHelper);
    } else {
      swapToken(liquidityPair, 0, wbnbAmount, swapHelper);
    }
    return wbnbAmount;
  }

  function autoSwap(address sender) private {
    // --------------------- Execute Auto Swap -------------------------
    address liquidityPair = liquidityPool;
    address swapHelper = swapHelperAddress;

    if (sender == liquidityPair) return;

    uint poolAmount = disabledAutoLiquidity ? accumulatedToPool : accumulatedToPool / 2;
    uint adminAmount = accumulatedToAdmin;
    uint marketingAmount = accumulatedToMarketing;
    uint totalAmount = poolAmount + adminAmount + marketingAmount;

    if (totalAmount < _minAmountToAutoSwap) return;

    // Execute auto swap
    uint amountOut = operateSwap(liquidityPair, swapHelper, totalAmount);

    // --------------------- Add Liquidity -------------------------
    if (poolAmount > 0) {
      if (!disabledAutoLiquidity) {
        uint amountToSend = (amountOut * poolAmount) / (totalAmount);
        (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
        bool reversed = isReversed(liquidityPair, WBNB);
        if (reversed) {
          uint112 temp = reserve0;
          reserve0 = reserve1;
          reserve1 = temp;
        }

        uint amountA;
        uint amountB;
        {
          uint amountBOptimal = (amountToSend * reserve1) / reserve0;
          if (amountBOptimal <= poolAmount) {
            (amountA, amountB) = (amountToSend, amountBOptimal);
          } else {
            uint amountAOptimal = (poolAmount * reserve0) / reserve1;
            assert(amountAOptimal <= amountToSend);
            (amountA, amountB) = (amountAOptimal, poolAmount);
          }
        }
        tokenTransferFrom(WBNB, swapHelper, liquidityPair, amountA);
        _balances[liquidityPair] += amountB;
        IPancakePair(liquidityPair).mint(address(this));
      } else {
        uint amountToSend = (amountOut * poolAmount) / (totalAmount);
        tokenTransferFrom(WBNB, swapHelper, address(this), amountToSend);
      }
    }

    // --------------------- Transfer Swapped Amount -------------------------
    if (adminAmount > 0) {
      uint amountToSend = (amountOut * adminAmount) / (totalAmount);
      tokenTransferFrom(WBNB, swapHelper, administrationWallet, amountToSend);
    }
    if (marketingAmount > 0) {
      uint amountToSend = (amountOut * marketingAmount) / (totalAmount);
      tokenTransferFrom(WBNB, swapHelper, marketingWallet, amountToSend);
    }

    accumulatedToPool = 0;
    accumulatedToAdmin = 0;
    accumulatedToMarketing = 0;
  }

  function splitFee(
    uint incomingFeeAmount,
    address sender,
    uint adminFee,
    uint poolFee,
    uint burnFee,
    uint marketingFee
  ) private {
    uint totalFee = adminFee + poolFee + burnFee + marketingFee;

    //Burn
    if (burnFee > 0) {
      uint burnAmount = (incomingFeeAmount * burnFee) / totalFee;
      _balances[address(this)] += burnAmount;
      _burn(address(this), burnAmount);
    }

    // Administrative distribution
    if (adminFee > 0) {
      accumulatedToAdmin += (incomingFeeAmount * adminFee) / totalFee;
      if (pausedSwapAdmin) {
        address wallet = administrationWallet;
        uint walletBalance = _balances[wallet] + accumulatedToAdmin;
        _balances[wallet] = walletBalance;
        emit Transfer(sender, wallet, accumulatedToAdmin);
        accumulatedToAdmin = 0;
      }
    }

    // Marketing distribution
    if (marketingFee > 0) {
      accumulatedToMarketing += (incomingFeeAmount * marketingFee) / totalFee;
      if (pausedSwapMarketing) {
        address wallet = marketingWallet;
        uint walletBalance = _balances[wallet] + accumulatedToMarketing;
        _balances[wallet] = walletBalance;
        emit Transfer(sender, wallet, accumulatedToMarketing);
        accumulatedToMarketing = 0;
      }
    }

    // Pool Distribution
    if (poolFee > 0) {
      accumulatedToPool += (incomingFeeAmount * poolFee) / totalFee;
      if (pausedSwapPool) {
        _balances[address(this)] += accumulatedToPool;
        emit Transfer(sender, address(this), accumulatedToPool);
        accumulatedToPool = 0;
      }
    }
  }

  function buyBackAndBurn(uint amount) external isAuthorized(3) {
    buyBack(amount, swapHelperAddress, liquidityPool, true);
  }

  function buyBackAndHold(uint amount, address receiver) external isAuthorized(3) {
    buyBack(amount, receiver, liquidityPool, false);
  }

  function buyBackAndLiquidity(uint amount, address receiver) external isAuthorized(3) {
    uint maxBalance = getTokenBalanceOf(WBNB, address(this));
    require(maxBalance >= amount, "Insufficient balance on contract");

    if (receiver == address(0)) receiver = address(this);

    address liquidityPair = liquidityPool;
    uint amountToSend = amount / 2;
    uint poolAmount = buyBack(amountToSend, swapHelperAddress, liquidityPool, false);

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, WBNB);
    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }
    uint amountA;
    uint amountB;
    {
      uint amountBOptimal = (amountToSend * reserve1) / reserve0;
      if (amountBOptimal <= poolAmount) {
        (amountA, amountB) = (amountToSend, amountBOptimal);
      } else {
        uint amountAOptimal = (poolAmount * reserve0) / reserve1;
        assert(amountAOptimal <= amountToSend);
        (amountA, amountB) = (amountAOptimal, poolAmount);
      }
    }
    tokenTransfer(WBNB, liquidityPair, amountA);

    require(_balances[swapHelperAddress] >= amountB, "Invalid SwapHelper Token Balance");
    _balances[liquidityPair] += amountB;
    _balances[swapHelperAddress] -= amountB;

    emit Transfer(swapHelperAddress, liquidityPair, amountB);
    IPancakePair(liquidityPair).mint(receiver);
  }

  function buyBack(
    uint amount,
    address wallet,
    address liquidityPair,
    bool burnTokens
  ) private returns (uint) {
    uint maxBalance = getTokenBalanceOf(WBNB, address(this));
    require(maxBalance >= amount, "Insufficient balance on contract");

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPair);
    bool reversed = isReversed(liquidityPair, address(this));

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }
    tokenTransfer(WBNB, liquidityPair, amount);
    uint tokenAmount = getAmountOut(amount, reserve1, reserve0);
    if (!reversed) {
      swapToken(liquidityPair, tokenAmount, 0, wallet);
    } else {
      swapToken(liquidityPair, 0, tokenAmount, wallet);
    }
    if (wallet == swapHelperAddress && burnTokens) _burn(swapHelperAddress, tokenAmount);
    return tokenAmount;
  }
}
