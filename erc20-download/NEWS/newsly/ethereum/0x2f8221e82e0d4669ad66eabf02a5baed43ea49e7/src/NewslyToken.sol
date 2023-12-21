// SPDX-License-Identifier: MIT

/*
 Newsly - The News Trading Terminal in Your Pocket
 Website: https://www.newsly.news/
 Twitter: https://twitter.com/newslybot
 Community: https://t.me/+Jm3OIlXxemc5ZDI0
 TG Bot: https://t.me/NewslyNews_bot
*/

pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";

contract NewslyToken is ERC20, Ownable {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    uint128 public immutable launchBlock;
    uint128 public immutable antibotPeriod;
    address public constant DEAD_ADDRESS = address(0xdead);

    address public teamWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    uint16 public buyTotalFees;
    uint16 public buyLiquidityFeePct;
    uint16 public buyTeamFeePct;

    uint16 public sellTotalFees;
    uint16 public sellLiquidityFeePct;
    uint16 public sellTeamFeePct;

    uint256 public tokensForLiquidity;
    uint256 public tokensForTeam;

    bool private _swapping;
    bool public limitsInEffect = true;
    bool public blacklistRenounced = false;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) _blacklisted;

    /******************/

    // exclude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event TeamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    constructor(IUniswapV2Router02 _uniswapRouter, uint128 _antibotPeriod) ERC20("Newsly", "NEWS") {

        launchBlock = uint128(block.number);
        antibotPeriod = _antibotPeriod; 

        excludeFromMaxTransaction(address(_uniswapRouter), true);
        uniswapV2Router = _uniswapRouter;

        uniswapV2Pair = IUniswapV2Factory(_uniswapRouter.factory())
            .createPair(address(this), _uniswapRouter.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 totalSupply = 100_000_000 * 1e18;

        maxTransactionAmount = totalSupply * 25 / 10000; // 0.25%
        maxWallet = totalSupply * 25 / 10000; // 0.25%
        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05% 

        buyLiquidityFeePct = 20;
        buyTeamFeePct = 80;
        buyTotalFees = 5;

        sellLiquidityFeePct = 20;
        sellTeamFeePct = 80;
        sellTotalFees = 5;

        teamWallet = owner(); // set as team wallet

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

    function updateBuyFees(
        uint16 _liquidityFeePercent,
        uint16 _teamFeePercent,
        uint16 _buyTotalFees
    ) external onlyOwner {
        buyLiquidityFeePct = _liquidityFeePercent;
        buyTeamFeePct = _teamFeePercent;
        require(_liquidityFeePercent + _teamFeePercent == 100, 'Total percent must be 100');
        buyTotalFees = _buyTotalFees;
        require(_buyTotalFees <= 5, "Buy fees must be <= 5.");
    }

    function updateSellFees(
        uint16 _liquidityFeePercent,
        uint16 _teamFeePercent,
        uint16 _sellTotalFees
    ) external onlyOwner {
        sellLiquidityFeePct = _liquidityFeePercent;
        sellTeamFeePct = _teamFeePercent;
        require(_liquidityFeePercent + _teamFeePercent == 100, 'Total percent must be 100');
        sellTotalFees = _sellTotalFees;
        require(_sellTotalFees <= 5, "Sell fees must be <= 5.");
    }

    function updateTeamWallet(address newWallet) external onlyOwner {
        emit TeamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
    }

    function withdrawStuckToken() external onlyOwner {
        uint256 balance = IERC20(address(this)).balanceOf(address(this));
        IERC20(address(this)).transfer(msg.sender, balance);
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawStuckErc20(address _token, address _to) external onlyOwner {
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

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner
    {
        isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner
    {
        require(
            pair != uniswapV2Pair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    // @dev team renounce blacklist commands
    function renounceBlacklist() public onlyOwner {
        blacklistRenounced = true;
    }

    function blacklist(address _addr) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(
            _addr != address(uniswapV2Pair) && _addr != address(uniswapV2Router), 
            "Cannot blacklist token's v2 router or v2 pool."
        );
        _blacklisted[_addr] = true;
    }

    // @dev blacklist v3 pools; can unblacklist() down the road to suit project and community
    function blacklistLiquidityPool(address lpAddress) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        require(
            lpAddress != address(uniswapV2Pair) && lpAddress != address(uniswapV2Router), 
            "Cannot blacklist token's v2 router or v2 pool."
        );
        _blacklisted[lpAddress] = true;
    }

    // @dev unblacklist address; not affected by blacklistRenounced incase team wants to unblacklist v3 pools down the road
    function unblacklist(address _addr) public onlyOwner {
        _blacklisted[_addr] = false;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!_blacklisted[from],"Sender _blacklisted");
        require(!_blacklisted[to],"Receiver _blacklisted");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool _limitsInEffect = limitsInEffect;

        if (_limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !_swapping
            ) {
                //when buy
                if (
                    automatedMarketMakerPairs[from] &&
                    !isExcludedMaxTransactionAmount[to]
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
                    !isExcludedMaxTransactionAmount[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
                } else if (!isExcludedMaxTransactionAmount[to]) {
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
            !_swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            _swapping = true;

            _swapBack();

            _swapping = false;
        }

        bool takeFee = !_swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = amount * _getSellTotalFees(_limitsInEffect) / 100;
                tokensForLiquidity += (fees * sellLiquidityFeePct) / 100;
                tokensForTeam += (fees * sellTeamFeePct) / 100;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = amount * _getBuyTotalFees(_limitsInEffect) / 100;
                tokensForLiquidity += (fees * buyLiquidityFeePct) / 100;
                tokensForTeam += (fees * buyTeamFeePct) / 100;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
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

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
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

    function _swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForTeam;
        bool success;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount * 20) {
            contractBalance = swapTokensAtAmount * 20;
        }

        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) / totalTokensToSwap / 2;
        uint256 amountToSwapForETH = contractBalance - liquidityTokens;

        uint256 initialETHBalance = address(this).balance;

        _swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance - initialETHBalance;
        uint256 ethForTeam = (ethBalance * tokensForTeam) / (totalTokensToSwap - (tokensForLiquidity / 2));

        uint256 ethForLiquidity = ethBalance - ethForTeam;

        tokensForLiquidity = 0;
        tokensForTeam = 0;

        (success, ) = address(teamWallet).call{value: ethForTeam}("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            _addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }
    }

    function _getSellTotalFees(bool _limitsInEffect) private view returns (uint256) {
        if(!_limitsInEffect)
            return sellTotalFees;

        uint256 _sellTotalFees = sellTotalFees;
        uint256 _launchBlock = launchBlock;
        uint256 _antibotPeriod = antibotPeriod;

        if(block.number > _launchBlock + _antibotPeriod)
            return sellTotalFees;

        uint256 progressThroughAntibot = block.number - _launchBlock;
        uint256 antiBotTax = 100 - (100 * progressThroughAntibot / _antibotPeriod);
        if(antiBotTax < _sellTotalFees)
            antiBotTax = _sellTotalFees;

        return antiBotTax;
    }

    function _getBuyTotalFees(bool _limitsInEffect) private view returns (uint256) {
        if(!_limitsInEffect)
            return buyTotalFees;
        
        uint256 _buyTotalFees = buyTotalFees;
        uint256 _launchBlock = launchBlock;
        uint256 _antibotPeriod = antibotPeriod;

        if(block.number > _launchBlock + _antibotPeriod)
            return _buyTotalFees;

        uint256 progressThroughAntibot = block.number - _launchBlock;
        uint256 antiBotTax = 100 - (100 * progressThroughAntibot / _antibotPeriod);
        if(antiBotTax < _buyTotalFees)
            antiBotTax = _buyTotalFees;

        return antiBotTax;
    }
}