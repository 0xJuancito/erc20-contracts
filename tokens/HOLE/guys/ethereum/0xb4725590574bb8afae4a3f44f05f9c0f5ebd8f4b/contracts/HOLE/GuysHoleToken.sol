/*******************************

    Telegram:   https://t.me/HoleGuys
    X:          https://x.com/HoleGuysEth
    Website:    https://holeguys.com
    
*******************************/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./HOLEDividends.sol";

contract GuysHoleToken is Ownable, ERC20 {
    IUniswapV2Router02 immutable router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    HOLEDividends public dividends;

    uint256 public swapBackAt;

    uint256 public maxWallet;

    uint256 totalFee = 5;
    uint256 dividendsFee = 3;

    bool private inSwap = false;
    address public marketingWallet;
    address public developmentWallet;
    address public uniswapV2Pair;

    mapping(address => uint256) public receiveBlock;

    constructor(address _owner) ERC20("Guys", "HOLE") {
        uint256 totalSupply = 1_000_000_000 ether;

        swapBackAt = (totalSupply * 1) / 1000; // 0.1%

        maxWallet = (totalSupply * 1) / 100; // 1%

        uniswapV2Pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        dividends = new HOLEDividends();

        dividends.excludeFromDividends(owner());
        dividends.excludeFromDividends(_owner);
        dividends.excludeFromDividends(address(this));
        dividends.excludeFromDividends(address(dividends));
        dividends.excludeFromDividends(address(router));
        dividends.excludeFromDividends(uniswapV2Pair);
        dividends.excludeFromDividends(address(0xdead));
        dividends.excludeFromDividends(address(0));

        marketingWallet = 0xc91932Bfb917F55407844bD6668D2F57D3e8eD66;
        developmentWallet = 0xbaA82C662B8305A8882BAE2a91FD2D59A8cCb7eb;

        _mint(_owner, totalSupply);
    }

    receive() external payable {}

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        dividends.setBalance(payable(msg.sender));
    }

    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        marketingWallet = _marketingWallet;
    }

    function setDevelopmentWallet(address _developmentWallet)
        external
        onlyOwner
    {
        developmentWallet = _developmentWallet;
    }

    function setDividends(address _dividends) external onlyOwner {
        dividends = HOLEDividends(payable(_dividends));

        dividends.excludeFromDividends(address(dividends));
        dividends.excludeFromDividends(address(this));
        dividends.excludeFromDividends(owner());
        dividends.excludeFromDividends(uniswapV2Pair);
        dividends.excludeFromDividends(address(router));
    }

    function setFee(uint256 _totalFee, uint256 _dividendsFee)
        external
        onlyOwner
    {
        require(_totalFee <= 5 && _dividendsFee <= _totalFee);
        totalFee = _totalFee;
        dividendsFee = _dividendsFee;
    }

    function setMaxHoldingPercent(uint256 percent) public onlyOwner {
        require(percent >= 1 && percent <= 100, "Invalid percent");
        maxWallet = (totalSupply() * percent) / 100;
    }

    function setSwapBackAt(uint256 value) external onlyOwner {
        require(value <= totalSupply() / 50);
        swapBackAt = value;
    }

    function stats(address account)
        external
        view
        returns (uint256 withdrawableDividends, uint256 totalDividends)
    {
        (, withdrawableDividends, totalDividends) = dividends.getAccount(
            account
        );
    }

    function claim() external {
        dividends.claim(msg.sender);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (
            from == uniswapV2Pair &&
            to != address(this) &&
            to != owner() &&
            to != address(router)
        ) {
            require(super.balanceOf(to) + amount <= maxWallet, "Max wallet");
        }

        uint256 swapAmount = balanceOf(address(this));

        if (swapAmount > swapBackAt) {
            swapAmount = swapBackAt;
        }

        if (
            swapBackAt > 0 &&
            swapAmount == swapBackAt &&
            !inSwap &&
            from != uniswapV2Pair
        ) {
            inSwap = true;

            swapTokensForETH(swapAmount);

            uint256 balance = address(this).balance;

            if (balance > 0) {
                withdraw(balance);
            }

            inSwap = false;
        }

        if (
            totalFee > 0 &&
            from != address(this) &&
            from != owner() &&
            from != address(router) &&
            (from == uniswapV2Pair || to == uniswapV2Pair)
        ) {
            uint256 feeTokens = (amount * totalFee) / 100;
            amount -= feeTokens;

            super._transfer(from, address(this), feeTokens);
        }

        super._transfer(from, to, amount);

        dividends.setBalance(payable(from));
        dividends.setBalance(payable(to));
    }

    function swapTokensForETH(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function sendFunds(address user, uint256 value) internal {
        if (value > 0) {
            (bool success, ) = user.call{value: value}("");
            success;
        }
    }

    function withdraw(uint256 amount) internal {
        uint256 dividendsShare = totalFee > 0
            ? (dividendsFee * 10000) / totalFee
            : 0;

        uint256 toDividends = (amount * dividendsShare) / 10000;
        uint256 toMarketing = (amount - toDividends);
        uint256 toDevelopment = toMarketing;

        sendFunds(marketingWallet, toMarketing);
        sendFunds(developmentWallet, toDevelopment);
        sendFunds(address(dividends), toDividends);
    }
}
