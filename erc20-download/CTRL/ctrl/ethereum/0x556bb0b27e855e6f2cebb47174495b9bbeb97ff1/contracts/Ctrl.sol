// SPDX-License-Identifier: AGPL-3.0-only

/*

website: https://ctrlapp.io
twitter: https://twitter.com/ctrlappio
telegram: https://t.me/ctrlappio
discord: https://discord.gg/sQukANJv2t

*/

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";

/*

The CTRL token is governed and distributed by CTRL Foundation, a series of Wrappr LLC, a Marshall Islands limited liability company, Reg. No. 965909.

Trading of CTRL is not permitted in the United States or any other jurisdiction where prohibited by law including but not limited to: 
Belarus, Cuba, Crimea Region, Democratic Republic of Congo, Iran, Iraq, New Zealand, North Korea, South Sudan, Sudan, Syria, 
United States of America and its territories (American Samoa, Guam, Puerto Rico, the Northern Mariana Islands, 
and the U.S. Virgin Islands), Zimbabwe.

*/

contract CTRL is ERC20, Ownable {
    using SafeMath for uint256;

    event SwapBackSuccess(
        uint256 tokenAmount,
        uint256 ethAmountReceived,
        bool success
    );

    bool private swapping;

    address public rewardDistributor;
    address public treasuryWallet;

    uint256 _totalSupply = 10_000_000 * 1e18;

    uint256 public maxTransactionAmount = (_totalSupply * 10) / 1000;
    uint256 public swapTokensAtAmount = (_totalSupply * 10) / 100000;
    uint256 public maxWallet = (_totalSupply * 10) / 1000;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    uint256 public buyFees = 50;
    uint256 public sellFees = 50;

    uint256 public revshareAmount = 40;
    uint256 public devAmount = 60;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;
    mapping(address => bool) public automatedMarketMakerPairs;

    constructor() ERC20("CTRL", "CTRL") {
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);

        _mint(owner(), _totalSupply);
    }

    receive() external payable {}

    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
    }

    function removeLimits() external onlyOwner {
        buyFees = 5;
        sellFees = 5;
        limitsInEffect = false;
    }

    function reduceFees(uint buyFees_, uint sellFees_) external onlyOwner {
        require(
            buyFees_ <= buyFees && sellFees_ <= sellFees,
            "CTRL/REDUCE_ONLY"
        );

        buyFees = buyFees_;
        sellFees = sellFees_;
    }

    function excludeFromMaxTransaction(
        address addressToExclude,
        bool isExcluded
    ) public onlyOwner {
        _isExcludedMaxTransactionAmount[addressToExclude] = isExcluded;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(pair != uniswapV2Pair, "CTRL/CANT_REMOVE_UNIV2");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function createPair() external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        excludeFromMaxTransaction(address(uniswapV2Router), true);
        _approve(address(this), address(uniswapV2Router), totalSupply());

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
    }

    function updateFeeWallet(
        address rewardDistributor_,
        address treasuryWallet_
    ) public onlyOwner {
        treasuryWallet = treasuryWallet_;
        rewardDistributor = rewardDistributor_;

        excludeFromFees(rewardDistributor, true);
        excludeFromFees(treasuryWallet, true);

        excludeFromMaxTransaction(rewardDistributor, true);
        excludeFromMaxTransaction(treasuryWallet, true);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !swapping
            ) {
                if (!tradingActive) {
                    require(
                        _isExcludedFromFees[from] || _isExcludedFromFees[to],
                        "Trading is not enabled yet."
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
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Max wallet exceeded"
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
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Max wallet exceeded"
                    );
                }
            }
        }

        if (
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

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;

        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellFees > 0) {
                fees = amount.mul(sellFees).div(100);
            } else if (automatedMarketMakerPairs[from] && buyFees > 0) {
                fees = amount.mul(buyFees).div(100);
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
            amount -= fees;
        }
        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
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
        uint256 contractBalance = balanceOf(address(this));
        bool success;
        if (contractBalance == 0) {
            return;
        }
        if (contractBalance >= swapTokensAtAmount) {
            uint256 amountToSwapForETH = swapTokensAtAmount;

            swapTokensForEth(amountToSwapForETH);

            uint256 ethBalance = address(this).balance;

            uint256 amountToRevshare = ethBalance.mul(revshareAmount).div(100);

            uint256 amountToTreasury = ethBalance.sub(amountToRevshare);

            (success, ) = address(rewardDistributor).call{
                value: amountToRevshare
            }("");

            (success, ) = address(treasuryWallet).call{value: amountToTreasury}(
                ""
            );

            emit SwapBackSuccess(amountToSwapForETH, ethBalance, success);
        }
    }
}
