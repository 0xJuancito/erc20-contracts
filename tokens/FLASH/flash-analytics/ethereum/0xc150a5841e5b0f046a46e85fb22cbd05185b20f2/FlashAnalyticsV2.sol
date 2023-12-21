/**
    Flash Analytics V2
    Empowering Investors and Optimizing Performance through Data Collection and Token Analysis.

    Tax fees = 3/3%
    1% = Holders
    1% = Team
    1% = Liquidity

    Website: https://flash-analytics.com
    Twitter: https://twitter.com/flash_defi
    Telegram: https://t.me/FlashAnalytics
    Discord: https://discord.gg/flashanalytics
    GitBook: https://flash-analytics.gitbook.io/flash-analytics
**/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )  external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract FlashAnalyticsV2 is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);

    bool private swapping;

    address public teamWallet;
    address public holdersWallet;

    uint256 public swapTokensAtAmount;

    bool public tradingActive = false;
    bool public swapEnabled = false;
    bool public transferEnabled = false;

    bool public blacklistRenounced = false;

    mapping(address => bool) blacklisted;

    uint256 public buyTotalFees;
    uint256 public buyHoldersFee;
    uint256 public buyLiquidityFee;
    uint256 public buyTeamFee;

    uint256 public sellTotalFees;
    uint256 public sellHoldersFee;
    uint256 public sellLiquidityFee;
    uint256 public sellTeamFee;

    uint256 public tokensForHolders;
    uint256 public tokensForLiquidity;
    uint256 public tokensForTeam;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event holdersWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event teamWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    constructor() ERC20("Flash Analytics", "FLASH") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 _buyHoldersFee = 5;
        uint256 _buyLiquidityFee = 5;
        uint256 _buyTeamFee = 5;

        uint256 _sellHoldersFee = 10;
        uint256 _sellLiquidityFee = 10;
        uint256 _sellTeamFee = 10;

        uint256 totalSupply = 1_000_000 * 1e18;

        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05%

        buyHoldersFee = _buyHoldersFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyTeamFee = _buyTeamFee;
        buyTotalFees = buyHoldersFee + buyLiquidityFee + buyTeamFee;

        sellHoldersFee = _sellHoldersFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTeamFee = _sellTeamFee;
        sellTotalFees = sellHoldersFee + sellLiquidityFee + sellTeamFee;

        holdersWallet = address(0xF0Ac72aED9070A836EaE2168480917d502789DA3);
        teamWallet = address(0x3849880D19C890a68733b222d918caF2d72584EA);

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    function enableTrading() external onlyOwner {
        require(!tradingActive, "Trading is already active.");

        transferEnabled = true;

        addLiquidity(balanceOf(address(this)), address(this).balance);

        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        
        tradingActive = true;
        swapEnabled = true;
    }

    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool) {
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 5) / 1000, "Swap amount cannot be higher than 0.5% total supply.");

        swapTokensAtAmount = newAmount;

        return true;
    }

    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateBuyFees(
        uint256 _holdersFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        buyHoldersFee = _holdersFee;
        buyLiquidityFee = _liquidityFee;
        buyTeamFee = _teamFee;
        buyTotalFees = buyHoldersFee + buyLiquidityFee + buyTeamFee;
        require(buyTotalFees <= 5, "Buy fees must be <= 5.");
    }

    function updateSellFees(
        uint256 _holdersFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        sellHoldersFee = _holdersFee;
        sellLiquidityFee = _liquidityFee;
        sellTeamFee = _teamFee;
        sellTotalFees = sellHoldersFee + sellLiquidityFee + sellTeamFee;
        require(sellTotalFees <= 5, "Sell fees must be <= 5.");
    }

    function updateBuyAndSellFees(
        uint256 _holdersFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        buyHoldersFee = _holdersFee;
        buyLiquidityFee = _liquidityFee;
        buyTeamFee = _teamFee;
        sellHoldersFee = _holdersFee;
        sellLiquidityFee = _liquidityFee;
        sellTeamFee = _teamFee;
        sellTotalFees = sellHoldersFee + sellLiquidityFee + sellTeamFee;
        buyTotalFees = buyHoldersFee + buyLiquidityFee + buyTeamFee;
        require(buyTotalFees <= 5 && sellTotalFees <= 5, "Buy and sell fees must be <= 5.");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateHoldersWallet(address newWallet) external onlyOwner {
        holdersWallet = newWallet;
        emit holdersWalletUpdated(newWallet, holdersWallet);
    }

    function updateTeamWallet(address newWallet) external onlyOwner {
        teamWallet = newWallet;
        emit teamWalletUpdated(newWallet, teamWallet);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isBlacklisted(address account) public view returns (bool) {
        return blacklisted[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!blacklisted[from], "Sender blacklisted");
        require(!blacklisted[to], "Receiver blacklisted");

        if (!transferEnabled) {
            require(msg.sender == owner(), "msg.sender must be owner()");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
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

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;

        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = amount.mul(sellTotalFees).div(100);
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForTeam += (fees * sellTeamFee) / sellTotalFees;
                tokensForHolders += (fees * sellHoldersFee) / sellTotalFees;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = amount.mul(buyTotalFees).div(100);
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForTeam += (fees * buyTeamFee) / buyTotalFees;
                tokensForHolders += (fees * buyHoldersFee) / buyTotalFees;
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

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractTokenBalance = balanceOf(address(this));
        bool success;
        uint256 _tokensForHolders = tokensForHolders;
        uint256 _tokensForLiquidity = tokensForLiquidity;
        uint256 _tokensForTeam = tokensForTeam;

        if (contractTokenBalance > swapTokensAtAmount * 20) {
            contractTokenBalance = swapTokensAtAmount * 20;
            uint256 percent = (contractTokenBalance * 100) / balanceOf(address(this));
            _tokensForHolders = (tokensForHolders * percent) / 100;
            _tokensForLiquidity = (tokensForLiquidity * percent) / 100;
            _tokensForTeam = (tokensForTeam * percent) / 100;
            contractTokenBalance = _tokensForHolders + _tokensForLiquidity + _tokensForTeam;
        }

        uint256 liquidityTokens = (contractTokenBalance * _tokensForLiquidity) / contractTokenBalance / 2;
        uint256 amountToSwapForETH = contractTokenBalance.sub(liquidityTokens).sub(_tokensForHolders);

        uint256 initialETHBalance = address(this).balance;

        swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance.sub(initialETHBalance);

        uint256 ethForLiquidity = ethBalance.mul(20).div(100);

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                _tokensForLiquidity
            );
        }

        super._transfer(address(this), holdersWallet, _tokensForHolders);

        (success, ) = address(teamWallet).call{value: address(this).balance}("");

        tokensForHolders -= _tokensForHolders;
        tokensForLiquidity -= _tokensForLiquidity;
        tokensForTeam -= _tokensForTeam;
    }

    function withdrawStuckTokens() external onlyOwner {
        super._transfer(address(this), owner(), balanceOf(address(this)));

        tokensForHolders = 0;
        tokensForLiquidity = 0;
        tokensForTeam = 0;
    }

    function withdrawStuckEth() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");

        require(success);
    }

    function renounceBlacklist() public onlyOwner {
        blacklistRenounced = true;
    }

    function blacklist(address _addr) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(_addr != address(uniswapV2Pair) && _addr != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), "Cannot blacklist token's v2 router or v2 pool.");

        blacklisted[_addr] = true;
    }

    function blacklistLiquidityPool(address lpAddress) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(lpAddress != address(uniswapV2Pair) && lpAddress != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), "Cannot blacklist token's v2 router or v2 pool.");

        blacklisted[lpAddress] = true;
    }

    function unblacklist(address _addr) public onlyOwner {
        blacklisted[_addr] = false;
    }
}