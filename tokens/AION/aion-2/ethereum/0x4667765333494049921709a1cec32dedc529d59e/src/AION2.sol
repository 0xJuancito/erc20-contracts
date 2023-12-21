// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/uniswap-v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "lib/uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract AION is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool private swapping;

    address public revShareWallet;
    address public teamWallet;
    address public buyBackWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    uint256 public startBlock;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    bool public blacklistRenounced = false;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) blacklisted;

    uint256 public buyTotalFees;
    uint256 public buyRevShareFee;
    uint256 public buyLiquidityFee;
    uint256 public buyTeamFee;

    uint256 public sellTotalFees;
    uint256 public sellRevShareFee;
    uint256 public sellLiquidityFee;
    uint256 public sellTeamFee;

    uint256 public buyBackFee;

    uint256 public tokensForRevShare;
    uint256 public tokensForLiquidity;
    uint256 public tokensForTeam;
    uint256 public tokensForBuyBack;

    /******************/

    // exclude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event revShareWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event buyBackWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event teamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    constructor() ERC20("AION", "AION") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 _buyRevShareFee = 0;
        uint256 _buyLiquidityFee = 0;
        uint256 _buyTeamFee = 4;

        uint256 _sellRevShareFee = 0;
        uint256 _sellLiquidityFee = 0;
        uint256 _sellTeamFee = 4;

        uint256 _buyBackFee = 1;

        uint256 totalSupply = 1_000_000 * 1e18;

        maxTransactionAmount = 2500 * 1e18; // 0.25%
        maxWallet = 2500 * 1e18; // 0.25% 
        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05%

        buyBackFee = _buyBackFee;

        buyRevShareFee = _buyRevShareFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyTeamFee = _buyTeamFee;
        buyTotalFees = buyRevShareFee + buyLiquidityFee + buyTeamFee + buyBackFee;

        sellRevShareFee = _sellRevShareFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTeamFee = _sellTeamFee;
        sellTotalFees = sellRevShareFee + sellLiquidityFee + sellTeamFee + buyBackFee;

        revShareWallet = address(0xe44Cb4dBD91648Cb6932f71729aaf0ddfA8b761D); // set as revShare wallet
        buyBackWallet = address(0x99Ba381043475e78609D517685947402978c8233); // set as buyBack wallet
        teamWallet = address(0xE43a6d169590f3245D7868Fe19de45AA377cc56a); // set as team wallet

        blacklisted[address(0xE592427A0AEce92De3Edee1F18E0157C05861564)] = true; // uniswap v3 router

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
        startBlock = block.number;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount)
        external
        onlyOwner
        returns (bool)
    {
        require(
            newAmount >= (totalSupply() * 1) / 100000,
            "Swap amount cannot be lower than 0.001% total supply."
        );
        require(
            newAmount <= (totalSupply() * 5) / 1000,
            "Swap amount cannot be higher than 0.5% total supply."
        );
        swapTokensAtAmount = newAmount;
        return true;
    }

    function updateMaxTxnAmount(uint256 newNum) external onlyOwner {
        require(
            newNum >= ((totalSupply() * 5) / 1000) / 1e18,
            "Cannot set maxTransactionAmount lower than 0.5%"
        );
        maxTransactionAmount = newNum * (10**18);
    }

    function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
        require(
            newNum >= ((totalSupply() * 10) / 1000) / 1e18,
            "Cannot set maxWallet lower than 1.0%"
        );
        maxWallet = newNum * (10**18);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateBuyFees(
        uint256 _revShareFee,
        uint256 _liquidityFee,
        uint256 _teamFee,
        uint256 _buyBackFee
    ) external onlyOwner {
        buyRevShareFee = _revShareFee;
        buyLiquidityFee = _liquidityFee;
        buyTeamFee = _teamFee;
        buyBackFee = _buyBackFee;
        buyTotalFees = buyRevShareFee + buyLiquidityFee + buyTeamFee + buyBackFee;
        require(buyTotalFees <= 5, "Buy fees must be <= 10.");
    }

    function updateSellFees(
        uint256 _revShareFee,
        uint256 _liquidityFee,
        uint256 _teamFee,
        uint256 _buyBackFee
    ) external onlyOwner {
        sellRevShareFee = _revShareFee;
        sellLiquidityFee = _liquidityFee;
        sellTeamFee = _teamFee;
        buyBackFee = _buyBackFee;
        sellTotalFees = sellRevShareFee + sellLiquidityFee + sellTeamFee + buyBackFee;
        require(sellTotalFees <= 5, "Sell fees must be <= 10.");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
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

    function updateRevShareWallet(address newRevShareWallet) external onlyOwner {
        emit revShareWalletUpdated(newRevShareWallet, revShareWallet);
        revShareWallet = newRevShareWallet;
    }

    function updateBuyBackWallet(address newBuyBackWallet) external onlyOwner {
        emit buyBackWalletUpdated(newBuyBackWallet, buyBackWallet);
        buyBackWallet = newBuyBackWallet;
    }

    function updateTeamWallet(address newWallet) external onlyOwner {
        emit teamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isBlacklisted(address account) public view returns (bool) {
        return blacklisted[account];
    }

    function getMaxTXAmount() public {
        uint256 relativeBlock = block.number - startBlock;
        if (relativeBlock < 4) {
            maxTransactionAmount = 2500 * 1e18;
        } else if (relativeBlock >= 4 && relativeBlock < 10) {
            maxTransactionAmount = 5000 * 1e18;
        } else {
            maxTransactionAmount = 10000 * 1e18;
        }
    }

    function getMaxWalletAmount() public {
        uint256 relativeBlock = block.number - startBlock;
        if (relativeBlock == 0) {
            maxWallet = 2500 * 1e18;
        } else if (relativeBlock > 0 && relativeBlock < 10) {
            maxWallet = 5000 * 1e18;
        } else {
            maxWallet = 10000 * 1e18;
        }
    }

    function getBuyFee() public view returns (uint256) {
        uint256 relativeBlock = block.number - startBlock;

        // Adjust buy fee based on block
        if (relativeBlock == 0) return 75;
        if (relativeBlock == 1) return 70;
        if (relativeBlock == 2) return 60;
        if (relativeBlock == 3) return 50;
        if (relativeBlock == 4) return 40;
        if (relativeBlock == 5) return 30;
        if (relativeBlock == 6) return 20;
        if (relativeBlock == 7) return 10;
        if (relativeBlock >= 8) return buyTotalFees;
    }

    function getSellFee() public view returns (uint256) {
        uint256 relativeBlock = block.number - startBlock;
        // Adjust buy fee based on block
        if (relativeBlock == 0) return 75;
        if (relativeBlock == 1) return 70;
        if (relativeBlock == 2) return 60;
        if (relativeBlock == 3) return 50;
        if (relativeBlock == 4) return 40;
        if (relativeBlock == 5) return 30;
        if (relativeBlock == 6) return 20;
        if (relativeBlock == 7) return 10;
        if (relativeBlock >= 8 && relativeBlock < 20) return 8;
        if (relativeBlock >= 20) return sellTotalFees;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!blacklisted[from],"Sender blacklisted");
        require(!blacklisted[to],"Receiver blacklisted");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

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
                        "Trading is not active."
                    );
                }

                getMaxTXAmount();
                getMaxWalletAmount();

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

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        uint256 buyFees = getBuyFee();
        uint256 sellFees = getSellFee();
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellFees > 0) {
                fees = amount.mul(sellFees).div(100);
                tokensForLiquidity += (fees * sellLiquidityFee) / sellFees;
                tokensForTeam += (fees * sellTeamFee) / sellFees;
                tokensForRevShare += (fees * sellRevShareFee) / sellFees;
                tokensForBuyBack += (fees * buyBackFee) / sellFees;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyFees > 0) {
                fees = amount.mul(buyFees).div(100);
                tokensForLiquidity += (fees * buyLiquidityFee) / buyFees;
                tokensForTeam += (fees * buyTeamFee) / buyFees;
                tokensForRevShare += (fees * buyRevShareFee) / buyFees;
                tokensForBuyBack += (fees * buyBackFee) / buyFees;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
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


    function addLiquidity2(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForRevShare + tokensForTeam + tokensForBuyBack;
        bool success;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount * 20) {
            contractBalance = swapTokensAtAmount * 20;
        }

        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
            totalTokensToSwap /
            2;
        uint256 amountToSwapForETH = contractBalance.sub(liquidityTokens);

        uint256 initialETHBalance = address(this).balance;

        swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance.sub(initialETHBalance);

        uint256 ethForRevShare = ethBalance.mul(tokensForRevShare).div(totalTokensToSwap - (tokensForLiquidity / 2));
        
        uint256 ethForTeam = ethBalance.mul(tokensForTeam).div(totalTokensToSwap - (tokensForLiquidity / 2));

        uint256 ethForBuyBack = ethBalance.mul(tokensForBuyBack).div(totalTokensToSwap - (tokensForLiquidity / 2));

        uint256 ethForLiquidity = ethBalance - ethForRevShare - ethForTeam - ethForBuyBack;

        tokensForLiquidity = 0;
        tokensForRevShare = 0;
        tokensForTeam = 0;
        tokensForBuyBack = 0;

        (success, ) = address(teamWallet).call{value: ethForTeam}("");

        (success, ) = address(buyBackWallet).call{value: ethForBuyBack}("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity2(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }

        (success, ) = address(revShareWallet).call{value: address(this).balance}("");
    }

    function withdrawStuckAion() external onlyOwner {
        uint256 balance = IERC20(address(this)).balanceOf(address(this));
        IERC20(address(this)).transfer(msg.sender, balance);
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawStuckToken(address _token, address _to) external onlyOwner {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }

    // @dev team renounce blacklist commands
    function renounceBlacklist() public onlyOwner {
        blacklistRenounced = true;
    }

    function blacklist(address _addr) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(
            _addr != address(uniswapV2Pair) && _addr != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), 
            "Cannot blacklist token's v2 router or v2 pool."
        );
        blacklisted[_addr] = true;
    }

    // @dev blacklist v3 pools; can unblacklist() down the road to suit project and community
    function blacklistLiquidityPool(address lpAddress) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(
            lpAddress != address(uniswapV2Pair) && lpAddress != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), 
            "Cannot blacklist token's v2 router or v2 pool."
        );
        blacklisted[lpAddress] = true;
    }

    // @dev unblacklist address; not affected by blacklistRenounced 
    function unblacklist(address _addr) public onlyOwner {
        blacklisted[_addr] = false;
    }
}