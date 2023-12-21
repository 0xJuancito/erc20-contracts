/* 
Links: orangebot.io / @the_orange_bot

Fair launch -> team revenue from 5% buy/sell tax
Liquidity locked 1 year on Unicrypt
Tokens unlock linearly in 1 year
Ownership renounced

Have fun, min token required to access Orange Bot Alpha will be announced on Twitter.
*/

import "./ERC20.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";

pragma solidity ^0.8.9;

contract ORBOT is ERC20, Ownable {
    address private WETH;
    address public constant uniswapV2Router02 =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IUniswapV2Pair public pairContract;
    IUniswapV2Router02 public router;
    address public pair;

    mapping(address => uint256) private buyBlock;

    address private feeReceiver = 0x79A033c186a6a011fBcB20E14Cbd458eE48c2fA0;

    uint16 public feeInitialPercentageBuy = 500;
    uint16 public feeInitialPercentageSell = 500;
    uint16 public feePercentageBuy = 500;
    uint16 public feePercentageSell = 500;
    uint16 public burnFeePercentage = 0;

    uint256 public maxTokenAmountPerWallet = 2000000 * 10 ** decimals();
    uint256 public maxTokenAmountPerTransaction = 0 * 10 ** decimals();

    uint256 private buyCount = 0;
    uint256 private initialBuyCountTreshold = 0;

    uint256 public swapTreshold = 100000000000000000;
    bool private inSwap = false;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() ERC20(unicode"Orange BOT", unicode"ORBOT") {
        router = IUniswapV2Router02(uniswapV2Router02);
        WETH = router.WETH();
        pair = IUniswapV2Factory(router.factory()).createPair(
            WETH,
            address(this)
        );
        pairContract = IUniswapV2Pair(pair);
        _approve(address(this), uniswapV2Router02, type(uint256).max);
        _approve(address(this), pair, type(uint256).max);
        _approve(msg.sender, uniswapV2Router02, type(uint256).max);
        _mint(msg.sender, (100000000) * 10 ** decimals());
    }

    receive() external payable {}

    modifier isBot(address from, address to) {
        require(
            block.number > buyBlock[from] || block.number > buyBlock[to],
            "Cannot perform more than one transaction in the same block"
        );
        _;
        buyBlock[from] = block.number;
        buyBlock[to] = block.number;
    }

    function checkMaxTransactionAmountExceeded(uint256 amount) private view {
        if (msg.sender != owner() || msg.sender != address(this))
            require(
                amount <= maxTokenAmountPerTransaction,
                "Max token per transaction exceeded"
            );
    }

    function checkMaxWalletAmountExceeded(
        address to,
        uint256 amount
    ) private view {
        if (msg.sender != owner() || to != address(this))
            require(
                balanceOf(to) + amount <= maxTokenAmountPerWallet,
                "Max token per wallet exceeded"
            );
    }

    function calculateTokenAmountInETH(
        uint256 amount
    ) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        try router.getAmountsOut(amount, path) returns (
            uint[] memory amountsOut
        ) {
            return amountsOut[1];
        } catch {
            return 0;
        }
    }

    function swapBalanceToETHAndSend() private lockTheSwap {
        uint256 amountIn = balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );
        payable(feeReceiver).transfer(address(this).balance);
    }

    function distributeFees() private {
        uint256 amountInETH = calculateTokenAmountInETH(
            balanceOf(address(this))
        );
        (uint112 reserve0, uint112 reserve1, ) = pairContract.getReserves();
        uint256 totalETHInPool;
        if (pairContract.token0() == WETH) totalETHInPool = uint256(reserve0);
        else if (pairContract.token1() == WETH)
            totalETHInPool = uint256(reserve1);
        if (amountInETH > swapTreshold) swapBalanceToETHAndSend();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override isBot(from, to) {
        if (
            from == owner() ||
            to == owner() ||
            from == feeReceiver ||
            to == feeReceiver ||
            from == feeReceiver ||
            to == feeReceiver ||
            inSwap
        ) {
            super._transfer(from, to, amount);
        } else {
            uint256 feePercentage = feePercentageBuy;
            bool buying = from == pair && to != uniswapV2Router02;
            bool selling = from != uniswapV2Router02 && to == pair;
            if (msg.sender != pair && !inSwap) distributeFees();
            if (buying) {
                if (buyCount < initialBuyCountTreshold) {
                    feePercentage = feeInitialPercentageBuy;
                    buyCount++;
                } else {
                    feePercentage = feePercentageBuy;
                }
            }
            if (selling) {
                if (buyCount < initialBuyCountTreshold) {
                    feePercentage = feeInitialPercentageSell;
                } else {
                    feePercentage = feePercentageSell;
                }
            }
            uint256 feeAmount = (amount * feePercentage) / (10000);
            uint256 burnFeeAmount = (amount * burnFeePercentage) / (10000);
            uint256 finalAmount = (amount - (feeAmount + burnFeeAmount));
            if (maxTokenAmountPerTransaction > 0)
                checkMaxTransactionAmountExceeded(amount);
            if (buying && maxTokenAmountPerWallet > 0)
                checkMaxWalletAmountExceeded(to, finalAmount);
            if (burnFeeAmount > 0) _burn(from, burnFeeAmount);
            super._transfer(from, address(this), feeAmount);
            super._transfer(from, to, finalAmount);
        }
    }

    function manualSwap() public {
        if (msg.sender == feeReceiver) {
            swapBalanceToETHAndSend();
        }
    }

    function removeLimits() public {
        if (msg.sender == feeReceiver) {
            maxTokenAmountPerWallet = 0;
            maxTokenAmountPerTransaction = 0;
        }
    }

    function removeTaxes() public {
        if (msg.sender == feeReceiver) {
            feePercentageBuy = 0;
            feePercentageSell = 0;
            burnFeePercentage = 0;
        }
    }
}