// SPDX-License-Identifier: MIT

// RavenFund - $RAVEN
//
// The raven symbolizes prophecy, insight, transformation, and intelligence. It also represents long-term success.
// The 1st AI-powered hedge fund
//
// https://www.ravenfund.app/
// https://twitter.com/RavenFund
// https://t.me/RavenFundPortal

pragma solidity ^0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RavenFund is IERC20, Ownable {
    using SafeMath for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                  constants                                 */
    /* -------------------------------------------------------------------------- */
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;
    uint256 constant MAX_FEE = 5;

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    address public SWAP_ROUTER_ADR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public SWAP_ROUTER;
    address public immutable SWAP_PAIR;

    string _name = "RavenFund";
    string _symbol = "RAVEN";

    uint256 _totalSupply = 10_000_000 ether;

    uint256 public _swapThreshold = (_totalSupply * 5) / 10000;

    mapping(address => uint256) public _balances;

    mapping(address => mapping(address => uint256)) _allowances;

    bool public enableTrading = false;
    bool public swapEnabled = false;
    bool inSwap;

    mapping(address => bool) public isFeeExempt;

    uint256 public buyFees = 5;
    uint256 public sellFees = 5;
    uint256 public transferFees = 0;

    address private rvnFundOpt;
    address private rvnFundTeam;
    address private adWallet;

    /* -------------------------------------------------------------------------- */
    /*                                  modifiers                                 */
    /* -------------------------------------------------------------------------- */
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    modifier onlyRvn() {
        require(msg.sender == owner() || msg.sender == rvnFundOpt || msg.sender == rvnFundTeam, "Only raven team wallets");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor() {
        // create uniswap pair
        SWAP_ROUTER = IUniswapV2Router02(SWAP_ROUTER_ADR);
        address _uniswapPair =
            IUniswapV2Factory(SWAP_ROUTER.factory()).createPair(address(this), SWAP_ROUTER.WETH());
        SWAP_PAIR = _uniswapPair;

        _allowances[address(this)][address(SWAP_ROUTER)] = type(uint256).max;
        _allowances[address(this)][msg.sender] = type(uint256).max;

        rvnFundOpt = address(0x2604ac3e76d34728e2d8b2878EBAAA1936989B00);
        rvnFundTeam = address(0x8892C1843e632B9649e0cC8AD09E26c0198f7e30);

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[rvnFundOpt] = true;
        isFeeExempt[rvnFundTeam] = true;
        isFeeExempt[ZERO] = true;
        isFeeExempt[DEAD] = true;

        uint256 distribute = _totalSupply * 90 / 100;
        _balances[msg.sender] = distribute;

        emit Transfer(address(0), msg.sender, distribute);

        distribute = _totalSupply * 10 / 100;
        _balances[rvnFundTeam] = distribute;

        emit Transfer(address(0), rvnFundTeam, distribute);
    }

    receive() external payable {}

    /* -------------------------------------------------------------------------- */
    /*                                    ERC20                                   */
    /* -------------------------------------------------------------------------- */
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

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "ERC20: insufficient allowance");
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    views                                   */
    /* -------------------------------------------------------------------------- */
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
        return _balances[account];
    }

    
    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(DEAD) - balanceOf(ZERO);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   owners                                   */
    /* -------------------------------------------------------------------------- */

    function clearStuckBalance() external onlyRvn {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
    function clearStuckToken() external onlyRvn {
        _transferFrom(address(this), msg.sender, balanceOf(address(this)));
    }

    function setSwapBackSettings(bool _enabled, uint256 _pt) external onlyOwner {
        swapEnabled = _enabled;
        _swapThreshold = (_totalSupply * _pt) / 10000;
    }

    function manualSwapBack() external onlyOwner {
        if (_shouldSwapBack()) {
            _swapBack();
        }
    }

    function startTrading() external onlyOwner {
        require(!enableTrading, "Token launched");
        enableTrading = true;
        swapEnabled = true;
    }

    function setIsFeeExempt(address wallet, bool exempt) external onlyOwner {
        isFeeExempt[wallet] = exempt;
    }

    function setAdWallet(address ad) external onlyOwner {
        adWallet = ad;
    }

    function updateFees(uint256 b_, uint256 s_, uint256 t_) external onlyOwner {
        require(b_ <= MAX_FEE, "Buy tax cannot be upper than 5%");
        require(s_ <= MAX_FEE, "Sell tax cannot be upper than 5%");
        require(t_ <= MAX_FEE, "Sell tax cannot be upper than 5%");
        buyFees = b_;
        sellFees = s_;
        transferFees = t_;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   private                                  */
    /* -------------------------------------------------------------------------- */

    
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(sender != DEAD, "Please use a good address");
        require(sender != ZERO, "Please use a good address");

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (!enableTrading) {
            if (sender == owner() || sender == rvnFundOpt || sender == rvnFundTeam || sender == adWallet){
                return _basicTransfer(sender, recipient, amount);
            } else {
                revert("Trading not enabled yet, please wait.");
            }
        } else {
            if (sender == owner() || sender == rvnFundOpt || sender == rvnFundTeam || sender == adWallet){
                return _basicTransfer(sender, recipient, amount);
            }
        }

        if (_shouldSwapBack()) {
            _swapBack();
        }

        require(_balances[sender] >= amount, "Insufficient Balance");
        _balances[sender] = _balances[sender] - amount;

        uint256 fees = _takeFees(sender, recipient, amount);
        uint256 amountWithoutFees = amount;

        if (fees > 0) {
            amountWithoutFees -= fees;
            _balances[address(this)] = _balances[address(this)] + fees;
            emit Transfer(sender, address(this), fees);
        }

        _balances[recipient] = _balances[recipient] + amountWithoutFees;

        emit Transfer(sender, recipient, amountWithoutFees);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(_balances[sender] >= amount, "Insufficient Balance");
        require(sender != DEAD, "Please use a good address");
        require(sender != ZERO, "Please use a good address");
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _takeFees(address sender, address recipient, uint256 amount) internal view returns (uint256) {
        uint256 fees = 0;
        if(_shouldTakeFee(sender, recipient))
        {
            if (sender == SWAP_PAIR) { // BUY
                fees = amount.mul(buyFees).div(100);
            } else if (recipient == SWAP_PAIR) { // SELL
                fees = amount.mul(sellFees).div(100);
            } else { // TRANSFER
                fees = amount.mul(transferFees).div(100);
            }
        }
        return fees;
    }

    function _checkBalanceForSwapping() internal view returns (bool) {
        return balanceOf(address(this)) >= _swapThreshold;
    }

    function _shouldSwapBack() internal view returns (bool) {
        return msg.sender != SWAP_PAIR && !inSwap && swapEnabled && _checkBalanceForSwapping();
    }

    function _swapBack() internal swapping {
        uint256 __swapThreshold = _swapThreshold;

        if (balanceOf(address(this)) > __swapThreshold * 20) {
            __swapThreshold = _swapThreshold * 20;
        }

        approve(address(SWAP_ROUTER), __swapThreshold);

        // swap
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = SWAP_ROUTER.WETH();

        SWAP_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            __swapThreshold, 0, path, address(this), block.timestamp
        );
        uint256 amountETH = address(this).balance;

        // send
        if (amountETH > 0) {
            (bool tmpSuccess1,) = payable(rvnFundOpt).call{value: amountETH.mul(60).div(100)}("");
            (bool tmpSuccess2,) = payable(rvnFundTeam).call{value: amountETH.mul(40).div(100)}("");
        }
    }

    function _shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }
}