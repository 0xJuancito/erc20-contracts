/**

    ░██████╗███████╗░█████╗░████████╗  ██████╗░░█████╗░████████╗
    ██╔════╝██╔════╝██╔══██╗╚══██╔══╝  ██╔══██╗██╔══██╗╚══██╔══╝
    ╚█████╗░█████╗░░██║░░╚═╝░░░██║░░░  ██████╦╝██║░░██║░░░██║░░░
    ░╚═══██╗██╔══╝░░██║░░██╗░░░██║░░░  ██╔══██╗██║░░██║░░░██║░░░
    ██████╔╝███████╗╚█████╔╝░░░██║░░░  ██████╦╝╚█████╔╝░░░██║░░░
    ╚═════╝░╚══════╝░╚════╝░░░░╚═╝░░░  ╚═════╝░░╚════╝░░░░╚═╝░░░

    Official Telegram: https://t.me/SectTokenPortal
    Official Twitter: https://twitter.com/thesectbot
    Official Website: https://sectbot.com
    Official Whitepaper: https://sectbot.gitbook.io/sect-bot-whitepaper/
    
    

    Sect Bot stands as the most advanced call tracking bot on the market, designed to significantly improve the monitoring and evaluation process of various calls posted within Telegram groups.
 
    It operates on an automated detection mechanism that tracks gains after each call, followed by a data analysis that ranks top performers on a dynamic leaderboard.

    Sect Bot not only enhances transparency but also fosters healthy competition among Individual group members. This is accomplished through the weekly rewards system to stimulate the top-performing callers. 

    Simply holding #SECT tokens allows you to participate in revenue sharing.


    Add SectBot to your group now: https://t.me/sectleaderboardbot

**/
// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
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

contract SectBot is Context, IERC20, Ownable {
    uint256 private constant _totalSupply = 10_000_000e18;
    uint256 private constant onePercent = 50_000e18;
    uint256 private minSwap = 5_000e18;
    uint256 private maxSwap = onePercent;

    IUniswapV2Router02 immutable uniswapV2Router;
    address immutable uniswapV2Pair;
    address immutable WETH;
    address payable immutable marketingWallet;

    uint64 public buyTax;
    uint64 public sellTax;

    uint8 private launch;
    uint8 private inSwapAndLiquify;
    uint64 public lastLiquifyTime;

    uint256 public maxTxAmount = onePercent; //max Tx for first mins after launch

    string private constant _name = "Sect Bot";
    string private constant _symbol = "SECT";

    mapping(address => uint256) private _balance;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFeeWallet;

    constructor() {
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        WETH = uniswapV2Router.WETH();
        buyTax = 35;
        sellTax = 40;

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            WETH
        );

        marketingWallet = payable(0x897FFA980758Fc7872c4515B929DcA60414db77A);
        _isExcludedFromFeeWallet[marketingWallet] = true;
        _isExcludedFromFeeWallet[msg.sender] = true;
        _isExcludedFromFeeWallet[address(this)] = true;
        _allowances[address(this)][address(uniswapV2Router)] = type(uint256)
            .max;
        _allowances[msg.sender][address(uniswapV2Router)] = type(uint256).max;
        _allowances[marketingWallet][address(uniswapV2Router)] = type(uint256)
            .max;

        _balance[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function openTrading() external onlyOwner {
        launch = 1;
        lastLiquifyTime = uint64(block.number);
    }

    function addExcludedWallet(address wallet) external onlyOwner {
        _isExcludedFromFeeWallet[wallet] = true;
    }

    function removeLimits() external onlyOwner {
        maxTxAmount = _totalSupply;
    }

    function changeTax(uint64 newBuyTax, uint64 newSellTax) external onlyOwner {
        require(newBuyTax < 100 && newSellTax < 100, "Max");
        buyTax = newBuyTax;
        sellTax = newSellTax;
    }

    function changeMaxSwapThreshold(
        uint256 newMaxSwapThreshold
    ) external onlyOwner {
        require(
            newMaxSwapThreshold * 1e18 > minSwap,
            "Max Swap cannot be less than min swap"
        );
        maxSwap = newMaxSwapThreshold * 1e18;
    }

    function changeMinSwapThreshold(
        uint256 newMinSwapThreshold
    ) external onlyOwner {
        require(
            newMinSwapThreshold * 1e18 < maxSwap,
            "Min Swap cannot be greater than max swap"
        );
        minSwap = newMinSwapThreshold * 1e18;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        if (amount <= 1e9) {
            //Small amounts
            _balance[from] -= amount;
            _balance[to] += amount;
            emit Transfer(from, to, amount);
            return;
        }
        uint256 _tax;
        if (_isExcludedFromFeeWallet[from] || _isExcludedFromFeeWallet[to]) {
            _tax = 0;
        } else {
            require(
                launch != 0 && amount <= maxTxAmount,
                "Launch / Max TxAmount 1% at launch"
            );

            if (inSwapAndLiquify == 1) {
                //In swapback
                _balance[from] -= amount;
                _balance[to] += amount;
                emit Transfer(from, to, amount);
                return;
            }

            //Buy
            if (from == uniswapV2Pair) {
                _tax = buyTax;
            } else if (to == uniswapV2Pair) {
                //Sell
                uint256 tokensToSwap = _balance[address(this)];

                if (
                    tokensToSwap > minSwap &&
                    inSwapAndLiquify == 0 &&
                    lastLiquifyTime != uint64(block.number)
                ) {
                    if (tokensToSwap > maxSwap) {
                        tokensToSwap = maxSwap;
                    }

                    swapback(tokensToSwap);
                }

                _tax = sellTax;
            } else {
                //Normal Transfer
                _tax = 0;
            }
        }

        //Is there tax for sender|receiver?
        if (_tax != 0) {
            //Tax transfer
            uint256 taxTokens = (amount * _tax) / 100;
            uint256 transferAmount = amount - taxTokens;

            _balance[from] -= amount;
            _balance[to] += transferAmount;
            _balance[address(this)] += taxTokens;
            emit Transfer(from, address(this), taxTokens);
            emit Transfer(from, to, transferAmount);
        } else {
            //No tax transfer
            _balance[from] -= amount;
            _balance[to] += amount;
            emit Transfer(from, to, amount);
        }
    }

    function swapback(uint256 tokensToSwap) internal {
        inSwapAndLiquify = 1;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSwap,
            0,
            path,
            marketingWallet,
            block.timestamp
        );
        lastLiquifyTime = uint64(block.number);
        inSwapAndLiquify = 0;
    }

    receive() external payable {}
}