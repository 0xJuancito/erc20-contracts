// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract OSMO is IERC20, Ownable {
    using SafeMath for uint256;
    IUniswapV2Router02 router;
    string private constant _name = "Osmo Bot";
    string private constant _symbol = "OSMO";
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isFeeExempt;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply = 1_000_000 * (10 ** _decimals);
    uint256 private init = 0;
    uint256 private startEnd = 15;
    uint256 private buyFee = 300;
    uint256 private sellFee = 300;
    uint256 private startFee = 3000;
    uint256 private transferFee = 0;
    uint256 private denominator = 10000;
    uint256 public swapTimes = 0;
    uint256 private swapCounter = 10;
    uint256 private swapThreshold = (_totalSupply * 100) / 100000;
    uint256 private _minTokenAmount = (_totalSupply * 1) / 100000;
    bool private tradingOpen = false;
    bool private swapEnabled = true;
    bool private swapping;
    address public pair;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public marketing_receiver;

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() Ownable() {
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        marketing_receiver = msg.sender;
        isFeeExempt[address(this)] = true;
        isFeeExempt[marketing_receiver] = true;
        isFeeExempt[msg.sender] = true;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function setisExempt(address _address, bool _enabled) external onlyOwner {
        isFeeExempt[_address] = _enabled;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function preTxCheck(
        address sender,
        address recipient,
        uint256 amount
    ) internal view {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            amount > uint256(0),
            "Transfer amount must be greater than zero"
        );
        require(
            amount <= balanceOf(sender),
            "You are trying to transfer more than your balance"
        );
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        preTxCheck(sender, recipient, amount);
        checkTradingAllowed(sender, recipient);
        swapbackCounters(sender, recipient);
        swapBack(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount);
        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, amount)
            : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);
        emit Transfer(sender, recipient, amountReceived);
    }

    function setStructure(
        uint256 _buy,
        uint256 _sell,
        uint256 _trans
    ) external onlyOwner {
        buyFee = _buy;
        sellFee = _sell;
        transferFee = _trans;
        require(
            buyFee <= denominator.div(5) &&
                sellFee <= denominator.div(8) &&
                transferFee <= denominator.div(8),
            "buyFee and sellFee cannot be more than 20%"
        );
    }

    function swapbackCounters(address sender, address recipient) internal {
        if (recipient == pair && !isFeeExempt[sender]) {
            swapTimes += uint256(1);
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            marketing_receiver,
            block.timestamp
        );
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function shouldSwapBack(
        address sender,
        address recipient,
        uint256 amount
    ) internal view returns (bool) {
        bool aboveMin = amount >= _minTokenAmount;
        bool aboveThreshold = balanceOf(address(this)) >= swapThreshold;
        return
            !swapping &&
            swapEnabled &&
            aboveMin &&
            !isFeeExempt[sender] &&
            recipient == pair &&
            swapTimes >= uint256(swapCounter) &&
            aboveThreshold;
    }

    function swapBack(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        if (shouldSwapBack(sender, recipient, amount)) {
            uint256 bal = balanceOf(address(this));
            if (bal >= (_totalSupply * 1) / 100) {
                bal = (_totalSupply * 1) / 100;
            }
            swapTokensForETH(bal);
            swapTimes = uint256(0);
        }
    }

    function shouldTakeFee(
        address sender,
        address recipient
    ) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }

    function getTotalFee(
        address sender,
        address recipient
    ) public view returns (uint256) {
        if (init >= block.number) {
            if (recipient == pair) {
                return
                    ((startFee - sellFee) *
                        (((init - block.number) * 10000) / startEnd)) /
                    10000 +
                    sellFee;
            }
            if (sender == pair) {
                return
                    ((startFee - buyFee) *
                        (((init - block.number) * 10000) / startEnd)) /
                    10000 +
                    buyFee;
            }
        } else {
            if (recipient == pair) {
                return sellFee;
            }
            if (sender == pair) {
                return buyFee;
            }
        }
        return transferFee;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        if (getTotalFee(sender, recipient) > 0) {
            uint256 feeAmount = amount.div(denominator).mul(
                getTotalFee(sender, recipient)
            );
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
            return amount.sub(feeAmount);
        }
        return amount;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function rescueERC20(address _address, uint256 _amount) external onlyOwner {
        IERC20(_address).transfer(msg.sender, _amount);
    }

    function launchTrading() external onlyOwner {
        require(!tradingOpen, "Trading already enabled");
        tradingOpen = true;
        init = block.number + startEnd;
    }

    function checkTradingAllowed(
        address sender,
        address recipient
    ) internal view {
        if (!isFeeExempt[sender] && !isFeeExempt[recipient]) {
            require(tradingOpen, "ERC20: Trading is not allowed");
        }
    }

    function rescueETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setMarketingWallet(address _wallet) external onlyOwner {
        marketing_receiver = _wallet;
    }
}
