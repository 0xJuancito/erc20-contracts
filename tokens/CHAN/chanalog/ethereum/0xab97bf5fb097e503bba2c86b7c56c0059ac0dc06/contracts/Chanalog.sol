// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
    Chancoin
    Your personal /biz/ analyst
    Organic engagement analyzer for cryptocurrencies on 4chan
    
    Website: https://chanalog.io
    Twitter: twitter.com/chanalog_
    Instagram: chanalog.io
    Tiktok: chanalog.io
**/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract Chanalog is ERC20Capped, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);

    bool private swapping;

    address public teamWallet;

    uint256 public swapTokensAtAmount;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    // Anti-bot and anti-whale mappings and variables
    // mapping(address => bool) blacklisted;

    uint256 public buyTotalFees;
    uint256 public buyTeamFee;

    uint256 public sellTotalFees;
    uint256 public sellTeamFee;

    uint256 public tokensForTeam;

    // When token was deployed
    uint256 public start;
    // start + time chosen by user
    uint256 public endPhase1;
    // start + endPhase1 + second time chosen by user
    uint256 public endPhase2;
    // If should apply custom fees
    bool public hasCustomPhases;
    // Phase 1 tax
    uint256 public phase1Tax;
    // Phase 2 tax
    uint256 public phase2Tax;
    // Minutes phase 1 is lasting
    uint256 public lengthPhase1;
    // Minutes phase 2 is lasting
    uint256 public lengthPhase2;

    /******************/

    // exclude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    bool public preMigrationPhase = true;
    mapping(address => bool) public preMigrationTransferrable;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event teamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    constructor() ERC20("Chanalog", "CHAN") ERC20Capped(21000000 * 10 ** decimals()) {

        _validateCustomPhases(10 minutes, 10 minutes, 70, 50);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // --> mainnet
        );

        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 _buyTeamFee = 4;

        uint256 _sellTeamFee = 4;

        uint256 totalSupply = 21_000_000 * 1e18;

        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05%

        buyTeamFee = _buyTeamFee;
        buyTotalFees = buyTeamFee;

        sellTeamFee = _sellTeamFee;
        sellTotalFees = sellTeamFee;

        teamWallet = owner(); // set as team wallet

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        preMigrationTransferrable[owner()] = true;

        ERC20Capped._mint(msg.sender, 21000000 * 10 ** decimals());
    }

    receive() external payable {}

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Capped) {
        require(totalSupply() + amount <= cap(), "Max number of tokens minted");
        super._mint(to, amount);
    }

    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
        preMigrationPhase = false;
    }

    function isTradingEnabled() external view returns (bool) {
        if (tradingActive && swapEnabled && !preMigrationPhase) {
            return true;
        } else {
            return false;
        }
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

    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateBuyFees(
        uint256 _teamFee
    ) external onlyOwner {
        buyTeamFee = _teamFee;
        buyTotalFees = buyTeamFee;
        require(buyTotalFees <= 5, "Buy fees must be <= 5.");
    }

    function updateSellFees(
        uint256 _teamFee
    ) external onlyOwner {
        sellTeamFee = _teamFee;
        sellTotalFees = sellTeamFee;
        require(sellTotalFees <= 5, "Sell fees must be <= 5.");
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

    function updateTeamWallet(address newWallet) external onlyOwner {
        emit teamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _validateCustomPhases(uint256 _lengthPhase1, uint256 _lengthPhase2, uint256 _phase1Tax, uint256 _phase2Tax) private {
        uint256 rightNow = block.timestamp;
        require(_lengthPhase1 <= 20 minutes && _lengthPhase2 <= 20 minutes, "phases too long");

        start = rightNow;

        // If UNIX time of endPhase 1 is bigger than current time it means that user has set the phased taxes
        if ((_lengthPhase1 + rightNow) > rightNow) {
            // Checks if its within threshold
            require(_phase1Tax > 0 && _phase1Tax <= 70, "threshold1");
            require(_phase2Tax > 0 && _phase2Tax <= 50, "threshold2");

            endPhase1 = rightNow + _lengthPhase1;
            endPhase2 = rightNow + _lengthPhase1 + _lengthPhase2;

            phase1Tax = _phase1Tax;
            phase2Tax = _phase2Tax;

            hasCustomPhases = true;

            lengthPhase1 = _lengthPhase1;
            lengthPhase2 = _lengthPhase2;
        } else {
            hasCustomPhases = false;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (preMigrationPhase) {
            require(preMigrationTransferrable[from], "Not authorized to transfer pre-migration.");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        uint256 sellFee_;
        uint256 buyFee_;
        bool customDistr = true;

        if (hasCustomPhases && block.timestamp < (endPhase2 - lengthPhase2)) {
            sellFee_ = phase1Tax;
            buyFee_ = sellFee_;
        } else if (hasCustomPhases && block.timestamp < endPhase2) {
            sellFee_ = phase2Tax;
            buyFee_ = phase2Tax;
        } else {
            sellFee_ = sellTotalFees;
            buyFee_ = buyTotalFees;
            customDistr = false;
        }

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
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellFee_ > 0) {
                fees = amount.mul(sellFee_).div(100);
                tokensForTeam += (fees * sellTeamFee) / sellFee_;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyFee_ > 0) {
                fees = amount.mul(buyFee_).div(100);
                tokensForTeam += (fees * buyTeamFee) / buyFee_;
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

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForTeam;
        bool success;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount * 20) {
            contractBalance = swapTokensAtAmount * 20;
        }

        uint256 amountToSwapForETH = contractBalance;

        uint256 initialETHBalance = address(this).balance;

        swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance.sub(initialETHBalance);

        uint256 ethForTeam = ethBalance.mul(tokensForTeam).div(totalTokensToSwap);

        tokensForTeam = 0;

        (success, ) = address(teamWallet).call{value: ethForTeam}("");
    }

    function withdrawStuckChancoin() external onlyOwner {
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

    function setPreMigrationTransferable(address _addr, bool isAuthorized) public onlyOwner {
        preMigrationTransferrable[_addr] = isAuthorized;
        excludeFromFees(_addr, isAuthorized);
    }
}