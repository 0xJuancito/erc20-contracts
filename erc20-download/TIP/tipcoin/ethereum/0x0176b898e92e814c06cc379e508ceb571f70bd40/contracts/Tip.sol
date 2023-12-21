/* 

Website: https://thetipcoin.io
Twitter: https://twitter.com/tipcoineth

*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

library SafeMath {
    function tryAdd(uint a, uint b) internal pure returns (bool, uint) {
        unchecked {
            uint c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint a, uint b) internal pure returns (bool, uint) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint a, uint b) internal pure returns (bool, uint) {
        unchecked {
            if (a == 0) return (true, 0);
            uint c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint a, uint b) internal pure returns (bool, uint) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint a, uint b) internal pure returns (bool, uint) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint a, uint b) internal pure returns (uint) {
        return a + b;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        return a - b;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        return a * b;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        return a / b;
    }

    function mod(uint a, uint b) internal pure returns (uint) {
        return a % b;
    }

    function sub(
        uint a,
        uint b,
        string memory errorMessage
    ) internal pure returns (uint) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint a,
        uint b,
        string memory errorMessage
    ) internal pure returns (uint) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint a,
        uint b,
        string memory errorMessage
    ) internal pure returns (uint) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        );
}

contract Tip is ERC20, Ownable {
    using SafeMath for uint;

    IUniswapV2Router02 public immutable uniswapV2Router;

    address public constant DeadAddress = address(0xdead);

    address public PairAddress;

    address public taxWallet;

    mapping(address => bool) private _isExcludedFromFees;

    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    mapping(address => bool) public marketMakerPairs;

    mapping(address => bool) public authorizedEditors;

    mapping(uint => uint) private swapInBlock;

    uint public maxTransactionAmount;

    uint public swapTokensThreshold;

    uint public maxWallet;

    uint private buyFees;

    uint private sellFees;

    uint public tradingEnabledInBlock;

    uint private delayBlocks = 10;

    bool public limitsActive = true;

    bool public tradingEnabled = false;

    bool public swapEnabled = false;

    bool private swapping = false;

    constructor(address _taxWallet) ERC20("Tip", "TIP") {
        taxWallet = _taxWallet;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;

        PairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        _setMarketMakerPair(address(PairAddress), true);

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        excludeFromMaxTransaction(address(PairAddress), true);
        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        excludeFromFees(address(0xdead), true);
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);
        excludeFromFees(taxWallet, true);

        setAuthorizedEditor(msg.sender, true);

        uint totalSupply = 10_000_000_000 * 1e18;
        maxTransactionAmount = 10_000_000_000 * 1e18;
        maxWallet = 10_000_000_000 * 1e18;

        //1% of supply to start
        swapTokensThreshold = 100_000_000 * 1e18;

        buyFees = 50;
        sellFees = 50;

        _mint(msg.sender, 8_500_000_000 * 1e18);
        _mint(address(this), 1_500_000_000 * 1e18);
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        swapEnabled = true;
        tradingEnabledInBlock = block.number;
    }

    function excludeFromFees(address _address, bool _isExcluded) public onlyOwner {
        _isExcludedFromFees[_address] = _isExcluded;
    }

    function setAuthorizedEditor(address _address, bool _isAuthorized) public onlyOwner {
        authorizedEditors[_address] = _isAuthorized;
    }

    function excludeFromMaxTransaction(address _address, bool _isExcluded) public onlyOwner {
        _isExcludedMaxTransactionAmount[_address] = _isExcluded;
    }

    function setMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != PairAddress, "The pair cannot be removed from automated market maker pairs");

        _setMarketMakerPair(pair, value);
    }

    function _setMarketMakerPair(address pair, bool value) private {
        marketMakerPairs[pair] = value;
    }

    function removeLimits() external onlyOwner {
        limitsActive = false;
    }

    function send() external onlyOwner {
        bool success;
        (success, ) = address(taxWallet).call{value: address(this).balance}("");
    }

    function _transfer(
        address from,
        address to,
        uint amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint blockNum = block.number;

        if (limitsActive) {
            if (to != address(0) && to != address(0xdead) && from != owner() && to != owner() && !swapping) {
                if ((tradingEnabledInBlock + delayBlocks) >= blockNum) {
                    maxTransactionAmount = 50_000_000 * 1e18;
                    maxWallet = 50_000_000 * 1e18;

                    buyFees = 50;
                    sellFees = 50;
                } else if (blockNum > (tradingEnabledInBlock + delayBlocks) && blockNum <= tradingEnabledInBlock + 20) {
                    maxTransactionAmount = 200_000_000 * 1e18;
                    maxWallet = 200_000_000 * 1e18;

                    buyFees = 25;
                    sellFees = 25;
                } else {
                    maxTransactionAmount = 10_000_000_000 * 1e18;
                    maxWallet = 10_000_000_000 * 1e18;

                    buyFees = 5;
                    sellFees = 5;
                }

                if (!tradingEnabled) {
                    require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active");
                }

                if (marketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                    require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the max transaction");
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                } else if (marketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                    require(amount <= maxTransactionAmount, "Sell transfer amount exceeds the max transaction");
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                }
            }
        }

        uint contractBalance = balanceOf(address(this));

        bool canSwap = contractBalance >= swapTokensThreshold;

        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            (swapInBlock[blockNum] < 2) &&
            !marketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;

            swapBack();

            ++swapInBlock[blockNum];

            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint fees = 0;
        if (takeFee) {
            if (marketMakerPairs[to] && sellFees > 0) {
                fees = amount.mul(sellFees).div(100);
            } else if (marketMakerPairs[from] && buyFees > 0) {
                fees = amount.mul(buyFees).div(100);
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapBack() private {
        uint contractBalance = balanceOf(address(this));
        bool success;

        if (contractBalance == 0) {
            return;
        }

        if (contractBalance > swapTokensThreshold * 20) {
            contractBalance = swapTokensThreshold * 5;
        }

        uint amountToSwapForETH = contractBalance;

        swapTokensForEth(amountToSwapForETH);

        (success, ) = address(taxWallet).call{value: address(this).balance}("");
    }

    function lowerTaxes(uint _newBuyFee, uint _newSellFee) external {
        require(authorizedEditors[msg.sender], "Must be authorized to lower fees");
        require(_newBuyFee <= buyFees, "New fees must be lower than the current");
        require(_newSellFee <= sellFees, "New fees must be lower than the current");
        buyFees = _newBuyFee;
        sellFees = _newSellFee;
    }

    function lowerSwapThreshold(uint _newValue) external onlyOwner {
        require(_newValue <= swapTokensThreshold, "New threshold must be lower than the current");
        swapTokensThreshold = _newValue;
    }

    function addLiquidity() external payable onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        _approve(address(this), address(uniswapV2Router), type(uint).max);
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    receive() external payable {}
}
