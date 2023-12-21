/*
        [....     [... [......  [.. ..                      
      [..    [..       [..    [..    [..                    
    [..        [..     [..     [..         [..       [..    
    [..        [..     [..       [..     [.   [..  [..  [.. 
    [..        [..     [..          [.. [..... [..[..   [.. 
      [..     [..      [..    [..    [..[.        [..   [.. 
        [....          [..      [.. ..    [....     [.. [...
    
    ERC20 Token.

    https://otsea.xyz/
    https://t.me/OTSeaPortal
    https://twitter.com/OTSeaERC20
*/

// SPDX-License-Identifier: MIT

import "./OTSeaDividends.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

pragma solidity ^0.8.19;

contract OTSeaERC20 is Ownable, ERC20 {
    uint256 public maxWallet;
    address public uniswapV2Pair;
    IUniswapV2Router02 immutable router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    OTSeaDividends public dividends;

    uint256 SUPPLY = 100_000_000 * 10 ** 18;

    uint256 snipeFee = 30;
    uint256 totalFee = 5;

    bool private inSwap = false;
    address public marketingWallet;
    address public dividendsWallet;
    address payable public opWallet1;
    address payable public opWallet2;

    uint256 public openTradingBlock;

    mapping(address => uint256) public receiveBlock;

    uint256 public swapAt = SUPPLY / 1000; //0.1%

    constructor(
        address payable _opWallet1,
        address payable _opWallet2,
        address _dividendsWallet,
        address _marketingWallet
    ) payable ERC20("OTSea", "OTSea") {
        _mint(_marketingWallet, (SUPPLY * 100) / 1000);
        _mint(address(this), (SUPPLY * 900) / 1000);

        maxWallet = SUPPLY;
        opWallet1 = _opWallet1;
        opWallet2 = _opWallet2;
        marketingWallet = _marketingWallet;
        dividendsWallet = _dividendsWallet;

        dividends = new OTSeaDividends();

        dividends.excludeFromDividends(address(0));
        dividends.excludeFromDividends(address(dividends));
        dividends.excludeFromDividends(address(this));
        dividends.excludeFromDividends(owner());
    }

    receive() external payable {}

    function isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function updateDividends(address _dividends) external onlyOwner {
        dividends = OTSeaDividends(payable(_dividends));

        dividends.excludeFromDividends(address(0));
        dividends.excludeFromDividends(address(dividends));
        dividends.excludeFromDividends(address(this));
        dividends.excludeFromDividends(owner());
        dividends.excludeFromDividends(uniswapV2Pair);
        dividends.excludeFromDividends(address(router));
    }

    function updateFee(uint256 _totalFee) external onlyOwner {
        require(_totalFee <= 5, "Fee can only be lowered");
        totalFee = _totalFee;
    }

    function updateMaxHoldingPercent(uint256 percent) public onlyOwner {
        require(percent >= 1 && percent <= 100, "invalid percent");
        maxWallet = (SUPPLY * percent) / 100;
    }

    function updateSwapAt(uint256 value) external onlyOwner {
        require(value <= SUPPLY / 50);
        swapAt = value;
    }

    function stats(
        address account
    ) external view returns (uint256 withdrawableDividends, uint256 totalDividends) {
        (, withdrawableDividends, totalDividends) = dividends.getAccount(account);
    }

    function claim() external {
        dividends.claim(msg.sender);
    }

    function enterTheSea() external onlyOwner {
        address pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
        _approve(address(this), address(router), balanceOf(address(this)));
        router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );

        uniswapV2Pair = pair;
        openTradingBlock = block.number;
        dividends.excludeFromDividends(address(router));
        dividends.excludeFromDividends(pair);

        updateMaxHoldingPercent(1);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        if (uniswapV2Pair == address(0)) {
            require(
                from == address(this) || from == address(0) || from == owner() || to == owner(),
                "Not started"
            );
            super._transfer(from, to, amount);
            return;
        }

        if (
            from == uniswapV2Pair && to != address(this) && to != owner() && to != address(router)
        ) {
            require(super.balanceOf(to) + amount <= maxWallet, "max wallet");
        }

        uint256 swapAmount = balanceOf(address(this));

        if (swapAmount > swapAt) {
            swapAmount = swapAt;
        }

        if (swapAt > 0 && swapAmount == swapAt && !inSwap && from != uniswapV2Pair) {
            inSwap = true;

            swapTokensForEth(swapAmount);

            uint256 balance = address(this).balance;

            if (balance > 0) {
                withdraw(balance);
            }

            inSwap = false;
        }

        uint256 fee;

        if (block.number <= openTradingBlock + 4 && from == uniswapV2Pair) {
            require(!isContract(to));
            fee = snipeFee;
        } else if (totalFee > 0) {
            fee = totalFee;
        }

        if (fee > 0 && from != address(this) && from != owner() && from != address(router)) {
            uint256 feeTokens = (amount * fee) / 100;
            amount -= feeTokens;

            super._transfer(from, address(this), feeTokens);
        }

        super._transfer(from, to, amount);

        dividends.updateBalance(payable(from));
        dividends.updateBalance(payable(to));
    }

    function swapTokensForEth(uint256 tokenAmount) private {
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

    function sendFunds(address user, uint256 value) private {
        if (value > 0) {
            (bool success, ) = user.call{value: value}("");
            success;
        }
    }

    function withdraw(uint256 amount) private {
        uint256 toDividends = amount / 5;
        uint256 toOp1 = amount / 10;
        uint256 toOp2 = amount / 10;
        uint256 toMarketing = amount - toDividends - toOp1 - toOp2;

        sendFunds(opWallet1, toOp1);
        sendFunds(opWallet2, toOp2);
        sendFunds(marketingWallet, toMarketing);
        sendFunds(dividendsWallet, toDividends);
    }

    function closeDistribution() external onlyOwner {
        dividends.close();
    }

    function collect() external onlyOwner {
        dividends.collect();
    }

    function setDividendsWallet(address payable _dividendsWallet) external {
        require(msg.sender == dividendsWallet, "Not authorized");
        dividendsWallet = _dividendsWallet;
    }

    function setMarketingWallet(address payable _marketingWallet) external {
        require(msg.sender == marketingWallet, "Not authorized");
        marketingWallet = _marketingWallet;
    }

    function setOpWallet1(address payable _opWallet1) external {
        require(msg.sender == opWallet1, "Not authorized");
        opWallet1 = _opWallet1;
    }

    function setOpWallet2(address payable _opWallet2) external {
        require(msg.sender == opWallet2, "Not authorized");
        opWallet2 = _opWallet2;
    }
}
