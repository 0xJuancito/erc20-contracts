// SPDX-License-Identifier: MIT
/*

    $$$$$$$$\  $$$$$$\   $$$$$$\  $$$$$$$\  $$$$$$$$\ 
    \____$$  |$$  __$$\ $$  __$$\ $$  __$$\ $$  _____|
        $$  / $$ /  \__|$$ /  $$ |$$ |  $$ |$$ |      
       $$  /  $$ |      $$ |  $$ |$$$$$$$  |$$$$$\    
      $$  /   $$ |      $$ |  $$ |$$  __$$< $$  __|   
     $$  /    $$ |  $$\ $$ |  $$ |$$ |  $$ |$$ |      
    $$$$$$$$\ \$$$$$$  | $$$$$$  |$$ |  $$ |$$$$$$$$\ 
    \________| \______/  \______/ \__|  \__|\________|

*/
pragma solidity ^0.8.5;

import "./ERC20.sol";
import "./IPancake.sol";
import "./SwapHelper.sol";
import "./Ownable.sol";
import "./Strings.sol";

contract ZCore is Ownable, ERC20 {
      address constant DEAD = 0x000000000000000000000000000000000000dEaD;
      address constant ZERO = 0x0000000000000000000000000000000000000000;
      address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
      address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    string constant _name = "ZCore";
    string constant _symbol = "ZCR";

    // Token supply control
    uint8 constant decimal = 18;
    uint8 constant decimalUSDT = 18;
    uint256 constant maxSupply = 2_500_000_000 * (10 ** decimal);
    bool public tradingEnabled;

    // Fees in sell
    uint256 public sellfeeDevelopmentWallet = 300; // 3%
    uint256 public sellfeeDevelopmentWallet2 = 300; // 3%
    uint256 public sellfeeDevelopmentWallet3 = 500; // 5%

    // Fees in buy
    uint256 public buyfeeDevelopmentWallet = 300; // 3%

    // special wallet permissions
    mapping(address => bool) public exemptFee;
    address public liquidityPool;
    address public developingWallet;
    address public developingWallet2;
    address public developingWallet3;

    SwapHelper private swapHelper;

    address WBNB_USDT_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    address WBNB_TOKEN_PAIR;

    bool private _noReentrancy = false; 

    function getOwner() external view returns (address) { return owner(); }

    function getsellFeeTotal() public view returns(uint256) { return sellfeeDevelopmentWallet + sellfeeDevelopmentWallet2 + sellfeeDevelopmentWallet3; }
    function getbuyFeeTotal() public view returns(uint256) { return buyfeeDevelopmentWallet; }

    function getSwapHelperAddress() external view returns (address) { return address(swapHelper); }
    function setExemptFee(address account, bool operation) public onlyOwner { exemptFee[account] = operation; }

    function setDevelopingWallet(address account) public onlyOwner { developingWallet = account; }
    function setdevelopingWallet2(address account) public onlyOwner { developingWallet2 = account; }
    function setdevelopingWallet3(address account) public onlyOwner { developingWallet3 = account; }

    function setSellFeesForDevelopmentWallets(uint256 fee1, uint256 fee2, uint256 fee3) external onlyOwner {
        require(fee1 + fee2 + fee3 <= 1500, "Total fees cannot exceed 15%");

        sellfeeDevelopmentWallet = fee1;
        sellfeeDevelopmentWallet2 = fee2;
        sellfeeDevelopmentWallet3 = fee3;
    }

    function setBuyFeesForDevelopmentWallets(uint256 fee1) external onlyOwner {
        require(fee1 <= 1500, "Total fees cannot exceed 15%");

        buyfeeDevelopmentWallet = fee1;
    }

    receive() external payable { }

    constructor() ERC20(_name, _symbol) {
        PancakeRouter router = PancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        WBNB_TOKEN_PAIR = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));
        liquidityPool = WBNB_TOKEN_PAIR;

        exemptFee[address(this)] = true;
        exemptFee[DEAD] = true;
        address ownerWallet = 0x7F221FAFAb5B01E43e400CF640630FF0E561A7eC;
        exemptFee[ownerWallet] = true;

        developingWallet = 0x7F221FAFAb5B01E43e400CF640630FF0E561A7eC;
        developingWallet2 = 0x7F221FAFAb5B01E43e400CF640630FF0E561A7eC;
        developingWallet3 = 0x7F221FAFAb5B01E43e400CF640630FF0E561A7eC;

        exemptFee[developingWallet] = true;
        exemptFee[developingWallet2] = true;
        exemptFee[developingWallet3] = true;

        swapHelper = new SwapHelper();
        swapHelper.safeApprove(WBNB, address(this), type(uint256).max);
        swapHelper.transferOwnership(_msgSender());

        _mint(ownerWallet, maxSupply);
        tradingEnabled = false;
        transferOwnership(ownerWallet);
    }

    function decimals() public view override returns (uint8) { return decimal; }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
    require(!_noReentrancy, "ReentrancyGuard: reentrant call happens");
    _noReentrancy = true;
    require(sender != address(0) && recipient != address(0), "transfer from/to the zero address");
    require(tradingEnabled || exemptFee[sender], "Trading is currently disabled");

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "transfer amount exceeds your balance");
    uint256 newSenderBalance = senderBalance - amount;
    
    _balances[sender] = newSenderBalance;
    uint256 feeAmount = 0;
    uint256 transferAmount = amount;


    if (recipient == liquidityPool) {
    if (!exemptFee[sender]) {
        feeAmount = (getsellFeeTotal() * amount) / 10000;
        exchangeFeeParts(feeAmount);
    }
    } else if (sender == liquidityPool) {
    if (!exemptFee[recipient]) {
        feeAmount = (getbuyFeeTotal() * amount) / 10000;
        _balances[developingWallet] += feeAmount;
        emit Transfer(sender, developingWallet, feeAmount);
        transferAmount -= feeAmount;
    }
    }
    uint256 newRecipientAmount = _balances[recipient] + (amount - feeAmount);
    _balances[recipient] = newRecipientAmount;
    
    _noReentrancy = false;
    emit Transfer(sender, recipient, transferAmount);
    }

    function exchangeFeeParts(uint256 incomingFeeTokenAmount) private returns (bool) {
        if (incomingFeeTokenAmount == 0) return false;
        _balances[address(this)] += incomingFeeTokenAmount;

        address pairWbnbToken = WBNB_TOKEN_PAIR;
        if (_msgSender() == pairWbnbToken) return false;
        uint256 feeTokenAmount = _balances[address(this)];
        _balances[address(this)] = 0;

        // Gas optimization
        address wbnbAddress = WBNB;
        (uint112 reserve0, uint112 reserve1) = getTokenReserves(pairWbnbToken);
        bool reversed = isReversed(pairWbnbToken, wbnbAddress);
        if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }
        _balances[pairWbnbToken] += feeTokenAmount;
        address swapHelperAddress = address(swapHelper);
        uint256 wbnbBalanceBefore = getTokenBalanceOf(wbnbAddress, swapHelperAddress);

        uint256 wbnbAmount = getAmountOut(feeTokenAmount, reserve1, reserve0);
        swapToken(pairWbnbToken, reversed ? 0 : wbnbAmount, reversed ? wbnbAmount : 0, swapHelperAddress);
        uint256 wbnbBalanceNew = getTokenBalanceOf(wbnbAddress, swapHelperAddress);
        require(wbnbBalanceNew == wbnbBalanceBefore + wbnbAmount, "Wrong amount of swapped on WBNB");

        // Deep Stack problem avoid
        {
            // Gas optimization
            address usdtAddress = USDT;
            address pairWbnbUsdt = WBNB_USDT_PAIR;
            (reserve0, reserve1) = getTokenReserves(pairWbnbUsdt);
            reversed = isReversed(pairWbnbUsdt, wbnbAddress);
            if (reversed) { uint112 temp = reserve0; reserve0 = reserve1; reserve1 = temp; }

            uint256 usdtBalanceBefore = getTokenBalanceOf(usdtAddress, address(this));
            tokenTransferFrom(wbnbAddress, swapHelperAddress, pairWbnbUsdt, wbnbAmount);
            uint256 usdtAmount = getAmountOut(wbnbAmount, reserve0, reserve1);
            swapToken(pairWbnbUsdt, reversed ? usdtAmount : 0, reversed ? 0 : usdtAmount, address(this));
            uint256 usdtBalanceNew = getTokenBalanceOf(usdtAddress, address(this));
            require(usdtBalanceNew == usdtBalanceBefore + usdtAmount, "Wrong amount swapped on USDT");

            uint SellFee = getsellFeeTotal();
            if (sellfeeDevelopmentWallet > 0) tokenTransfer(usdtAddress, developingWallet, (usdtAmount * sellfeeDevelopmentWallet) / SellFee);
            if (sellfeeDevelopmentWallet2 > 0) tokenTransfer(usdtAddress, developingWallet2, (usdtAmount * sellfeeDevelopmentWallet2) / SellFee);
            if (sellfeeDevelopmentWallet3 > 0) tokenTransfer(usdtAddress, developingWallet3, (usdtAmount * sellfeeDevelopmentWallet3) / SellFee);
        }
        return true;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, 'Insufficient amount in');
        require(reserveIn > 0 && reserveOut > 0, 'Insufficient liquidity');
        uint256 amountInWithFee = amountIn * 9975;
        uint256 numerator = amountInWithFee  * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
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
        if (failed) revert("Unable to check the direction of token from the pair");
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
        if (failed) revert("Unable to transfer token to the address");
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
        if (failed) revert("Unable to transfer from token to the address");
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
        if (failed) revert("Unable to swap to the receiver");
    }

    // gas optimization on get balanceOf from BEP20 or ERC20 token
    function getTokenBalanceOf(address token, address holder) internal view returns (uint112 tokenBalance) {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), holder)
            failed := iszero(staticcall(gas(), token, emptyPointer, 0x24, emptyPointer, 0x40))
            tokenBalance := mload(emptyPointer)
        }
        if (failed) revert("Unable to get the balance from the wallet");
    }

    // gas optimization on get reserves from the liquidity pool
    function getTokenReserves(address pairAddress) internal view returns (uint112 reserve0, uint112 reserve1) {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
            failed := iszero(staticcall(gas(), pairAddress, emptyPointer, 0x4, emptyPointer, 0x40))
            reserve0 := mload(emptyPointer)
            reserve1 := mload(add(emptyPointer, 0x20))
        }
        if (failed) revert("Unable to get reserves from the pair");
    }

    function setWBNB_TOKEN_PAIR(address newPair) external onlyOwner { WBNB_TOKEN_PAIR = newPair; }
    function setWBNB_USDT_Pair(address newPair) external onlyOwner { WBNB_USDT_PAIR = newPair; }
    function getWBNB_TOKEN_PAIR() external view returns(address) { return WBNB_TOKEN_PAIR; }
    function getWBNB_USDT_Pair() external view returns(address) { return WBNB_USDT_PAIR; }
    event TokensReleased(address indexed beneficiary, uint256 amount);
}
