// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Seed is ERC20, Ownable {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);
    address public routerCA = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    mapping(address => bool) public automatedMarketMakerPairs;

    bool private swapping = false;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) public blocked;
    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;
    uint256 private launchBlock;

    // first 4 blocks after enabling trading, charge 10x tax
    uint256 private deadBlocks = 4;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    uint256 public buyTotalFees;
    uint256 public buyTreasuryFee;
    uint256 public buyBuybackFee;

    uint256 public sellTotalFees;
    uint256 public sellTreasuryFee;
    uint256 public sellBuybackFee;

    uint256 public feeFactor;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;

    address treasuryWallet =
        address(0x880C21f00A3e89B897473DB1019886633189Cf5f);
    address buyBackWallet = address(0xDE12beb9C9Fa3439354CD148A4c4d77C757Ab7d8);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event BoughtEarly(address indexed sniper);

    constructor() ERC20("Bonsai3", "SEED") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerCA);

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        // liquidity deployer wallet
        _isExcludedFromFees[0x3719ef5ec3cf824D7b1CB2B1cF0e492dd2D9C6Ec] = true;

        uint256 _totalSupply = 1_000_000_000 * 1 ether;

        buyTreasuryFee = 30; // 3.0%;
        buyBuybackFee = 10; // 1.0%;

        sellTreasuryFee = 30; // 3.0%;
        sellBuybackFee = 10; // 1.0%;

        buyTotalFees = buyTreasuryFee + buyBuybackFee;
        sellTotalFees = sellTreasuryFee + sellBuybackFee;

        feeFactor = 10;

        maxTransactionAmount = _totalSupply / 200; // 0.5% max txn
        swapTokensAtAmount = _totalSupply / 20000; // 0.005% swap wallet
        _mint(msg.sender, _totalSupply);
    }

    receive() external payable {}

    fallback() external payable {}

    function updateMaxTxnAmount(uint256 newNumInEth) external onlyOwner {
        require(
            newNumInEth >= (totalSupply() / 10000) / 1e18,
            "Cannot set maxTransactionAmount lower than 0.01%"
        );
        maxTransactionAmount = newNumInEth * (10 ** 18);
    }

    function enableTrading() external onlyOwner {
        require(!tradingActive, "Token launched");
        tradingActive = true;
        launchBlock = block.number;
        swapEnabled = true;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!blocked[from], "Sniper blocked");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead)
            ) {
                if (!tradingActive) {
                    require(
                        _isExcludedFromFees[from] || _isExcludedFromFees[to],
                        "Trading is not active."
                    );
                }

                //when buy
                if (
                    automatedMarketMakerPairs[from] &&
                    !_isExcludedMaxTransactionAmount[to]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Buy transfer amount exceeds the maxTransactionAmount."
                    );
                }
                //when sell
                else if (
                    automatedMarketMakerPairs[to] &&
                    !_isExcludedMaxTransactionAmount[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
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

        bool takeFee = true;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        uint256 treasuryFees = 0;
        uint256 buybackFees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * (sellTotalFees)) / feeFactor / 100;
                treasuryFees += (fees * sellTreasuryFee) / sellTotalFees;
                buybackFees += (fees * sellBuybackFee) / sellTotalFees;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / feeFactor / 100;
                treasuryFees += (fees * buyTreasuryFee) / buyTotalFees;
                buybackFees += (fees * buyBuybackFee) / buyTotalFees;
            }

            if (block.number <= launchBlock + deadBlocks) {
                treasuryFees = treasuryFees * 10;
                buybackFees = buybackFees * 10;
                fees = fees * 10;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
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

        swapTokensForEth(contractBalance);

        uint256 ethBalance = address(this).balance;

        uint256 ethForBuyBack = (ethBalance *
            (buyBuybackFee + sellBuybackFee)) / (buyTotalFees + sellTotalFees);

        uint256 ethForTreasury = ethBalance - ethForBuyBack;

        (success, ) = address(treasuryWallet).call{value: ethForTreasury}("");
        (success, ) = address(buyBackWallet).call{value: ethForBuyBack}("");
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

    function updateBuyTax(
        uint256 _treasuryTax, // 10 = 1%
        uint256 _buybackTax
    ) external onlyOwner {
        buyTreasuryFee = _treasuryTax;
        buyBuybackFee = _buybackTax;
        buyTotalFees = buyTreasuryFee + buyBuybackFee;
        require(buyTotalFees <= 10 * feeFactor); // max 10%
    }

    function updateSellTax(
        uint256 _treasuryTax, // 10 = 1%
        uint256 _buybackTax
    ) external onlyOwner {
        sellTreasuryFee = _treasuryTax;
        sellBuybackFee = _buybackTax;
        sellTotalFees = sellTreasuryFee + sellBuybackFee;
        require(sellTotalFees <= 10 * feeFactor); // max 10%
    }

    function multiBlock(
        address[] calldata blockees,
        bool shouldBlock
    ) external onlyOwner {
        for (uint256 i = 0; i < blockees.length; i++) {
            address blockee = blockees[i];
            if (
                blockee != address(this) &&
                blockee != routerCA &&
                blockee != address(uniswapV2Pair)
            ) blocked[blockee] = shouldBlock;
        }
    }

    function excludeFromMaxTransaction(
        address updAds,
        bool isEx
    ) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != uniswapV2Pair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }
}
