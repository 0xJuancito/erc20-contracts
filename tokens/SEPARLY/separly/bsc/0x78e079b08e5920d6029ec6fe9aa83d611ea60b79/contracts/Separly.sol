// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./libraries/DividendPayingToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Separly is ERC20, Ownable {
    using Address for address payable;

    uint256 private initialSupply = 1_000_000_000 * (10 ** 18);

    IUniswapV2Router02 public router;
    address public  pair;

    bool private swapping;
    bool public swapEnabled;
    bool public claimEnabled;

    SeparlyDividendTracker public dividendTracker;

    address public treasuryWallet;
    address public devWallet;

    uint256 private swapTokensAtAmount = 500_000 * 10 ** 18;

    struct Taxes {
        uint256 rewards;
        uint256 treasury;
        uint256 liquidity;
        uint256 dev;
    }

    Taxes public buyTaxes = Taxes(0, 0, 0, 0);
    Taxes public sellTaxes = Taxes(0, 0, 0, 0);

    uint256 public totalBuyTax = 0;
    uint256 public totalSellTax = 0;

    mapping(address => bool) public _isBot;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event SendDividends(uint256 tokensSwapped, uint256 amount);
    event ProcessedDividendTracker(uint256 iterations, uint256 claims, uint256 lastProcessedIndex, bool indexed automatic, uint256 gas, address indexed processor);

    constructor(address _treasuryWallet, address _devWallet) ERC20("Separly", "SEPARLY") {

        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_devWallet != address(0), "Invalid dev wallet");

        treasuryWallet = _treasuryWallet;
        devWallet = _devWallet;

        dividendTracker = new SeparlyDividendTracker();

        IUniswapV2Router02 _router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _pair = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;

        _setAutomatedMarketMakerPair(_pair, true);

        dividendTracker.updateLP_Token(pair);

        dividendTracker.excludeFromDividends(address(dividendTracker), true);
        dividendTracker.excludeFromDividends(address(this), true);
        dividendTracker.excludeFromDividends(owner(), true);
        dividendTracker.excludeFromDividends(address(0xdead), true);
        dividendTracker.excludeFromDividends(address(_router), true);

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(treasuryWallet, true);
        excludeFromFees(devWallet, true);

        _mint(owner(), initialSupply);
    }

    receive() external payable {}

    function updateDividendTracker(address newAddress) public onlyOwner {
        SeparlyDividendTracker newDividendTracker = SeparlyDividendTracker(payable(newAddress));

        newDividendTracker.excludeFromDividends(address(newDividendTracker), true);
        newDividendTracker.excludeFromDividends(address(this), true);
        newDividendTracker.excludeFromDividends(owner(), true);
        newDividendTracker.excludeFromDividends(address(router), true);
        dividendTracker = newDividendTracker;
    }

    function claim() external {
        require(claimEnabled, "Claim not enabled");
        dividendTracker.processAccount(payable(msg.sender));
    }

    function rescueETH20Tokens(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), IERC20(tokenAddress).balanceOf(address(this)));
    }

    function forceSend() external {
        uint256 ETHbalance = address(this).balance;
        payable(treasuryWallet).sendValue(ETHbalance);
    }

    function trackerRescueETH20Tokens(address tokenAddress) external onlyOwner {
        dividendTracker.trackerRescueETH20Tokens(owner(), tokenAddress);
    }

    function trackerForceSend() external onlyOwner {
        dividendTracker.trackerForceSend(owner());
    }

    function updateRouter(address newRouter) external onlyOwner {
        router = IUniswapV2Router02(newRouter);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function excludeFromDividends(address account, bool value) external onlyOwner {
        dividendTracker.excludeFromDividends(account, value);
    }

    function setTreasuryWallet(address newWallet) external onlyOwner {
        treasuryWallet = newWallet;
    }

    function setDevWallet(address newWallet) external onlyOwner {
        devWallet = newWallet;
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount * 10 ** 18;
    }

    function setBuyTaxes(uint256 _rewards, uint256 _treasury, uint256 _liquidity, uint256 _dev) external onlyOwner {
        require(_rewards + _treasury + _liquidity + _dev <= 20, "Fee must be <= 20%");
        buyTaxes = Taxes(_rewards, _treasury, _liquidity, _dev);
        totalBuyTax = _rewards + _treasury + _liquidity + _dev;
    }

    function setSellTaxes(uint256 _rewards, uint256 _treasury, uint256 _liquidity, uint256 _dev) external onlyOwner {
        require(_rewards + _treasury + _liquidity + _dev <= 20, "Fee must be <= 20%");
        sellTaxes = Taxes(_rewards, _treasury, _liquidity, _dev);
        totalSellTax = _rewards + _treasury + _liquidity + _dev;
    }

    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function setClaimEnabled(bool state) external onlyOwner {
        claimEnabled = state;
    }

    function setBot(address bot, bool value) external onlyOwner {
        require(_isBot[bot] != value);
        _isBot[bot] = value;
    }

    function setBulkBot(address[] memory bots, bool value) external onlyOwner {
        for (uint256 i; i < bots.length; i++) {
            _isBot[bots[i]] = value;
        }
    }

    function setLP_Token(address _lpToken) external onlyOwner {
        dividendTracker.updateLP_Token(_lpToken);
    }

    function setAutomatedMarketMakerPair(address newPair, bool value) external onlyOwner {
        _setAutomatedMarketMakerPair(newPair, value);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(automatedMarketMakerPairs[newPair] != value, "Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[newPair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(newPair, true);
        }

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getAccountInfo(address account)
    external view returns (
        address,
        uint256,
        uint256,
        uint256,
        uint256){
        return dividendTracker.getAccount(account);
    }

    function airdropTokens(address[] memory accounts, uint256[] memory amounts) external onlyOwner {
        require(accounts.length == amounts.length, "Arrays must have same size");
        for (uint256 i; i < accounts.length; i++) {
            super._transfer(msg.sender, accounts[i], amounts[i]);
        }
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (canSwap && !swapping && swapEnabled && automatedMarketMakerPairs[to] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            swapping = true;

            if (totalSellTax > 0) {
                swapAndLiquify(swapTokensAtAmount);
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (!automatedMarketMakerPairs[to] && !automatedMarketMakerPairs[from] && !_isBot[from]) takeFee = false;

        uint256 feeAmt = 0;

        if (takeFee) {
            if (automatedMarketMakerPairs[to]) feeAmt = amount * totalSellTax / 1_0_0;
            else if (automatedMarketMakerPairs[from]) feeAmt = amount * totalBuyTax / 1_0_0;
            if ((automatedMarketMakerPairs[to] || !automatedMarketMakerPairs[from]) && _isBot[from]) feeAmt = amount * 9_9 / 1_0_0;

            amount = amount - feeAmt;
        }

        super._transfer(from, to, amount);

        if (feeAmt > 0) super._transfer(from, address(this), feeAmt);

        try dividendTracker.setBalance(from, balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(to, balanceOf(to)) {} catch {}

    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 tokensToAddLiquidityWith = tokens / 2;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForETH(toSwap);

        uint256 ETHToAddLiquidityWith = address(this).balance - initialBalance;

        if (ETHToAddLiquidityWith > 0) {
            addLiquidity(tokensToAddLiquidityWith, ETHToAddLiquidityWith);
        }

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        uint256 totalTax = (totalSellTax - sellTaxes.liquidity);

        uint256 treasuryAmt = lpBalance * sellTaxes.treasury / totalTax;
        if (treasuryAmt > 0) {
            IERC20(pair).transfer(treasuryWallet, treasuryAmt);
        }

        uint256 devAmt = lpBalance * sellTaxes.dev / totalTax;
        if (devAmt > 0) {
            IERC20(pair).transfer(devWallet, devAmt);
        }

        uint256 dividends = lpBalance * sellTaxes.rewards / totalTax;
        if (dividends > 0) {
            bool success = IERC20(pair).transfer(address(dividendTracker), dividends);
            if (success) {
                dividendTracker.distributeLPDividends(dividends);
                emit SendDividends(tokens, dividends);
            }
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
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

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        _approve(address(this), address(router), tokenAmount);

        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

    }

}

contract SeparlyDividendTracker is Ownable, DividendPayingToken {
    using Address for address payable;

    struct AccountInfo {
        address account;
        uint256 withdrawableDividends;
        uint256 totalDividends;
        uint256 lastClaimTime;
    }

    mapping(address => bool) public excludedFromDividends;

    mapping(address => uint256) public lastClaimTimes;

    event ExcludeFromDividends(address indexed account, bool value);
    event Claim(address indexed account, uint256 amount);

    constructor()  DividendPayingToken("Separly_Dividends_Tracker", "Separly_Dividend_Tracker") {}

    function trackerRescueETH20Tokens(address recipient, address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).transfer(recipient, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function trackerForceSend(address recipient) external onlyOwner {
        uint256 ETHbalance = address(this).balance;
        payable(recipient).sendValue(ETHbalance);
    }

    function updateLP_Token(address _lpToken) external onlyOwner {
        LP_Token = _lpToken;
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "No transfers allowed");
    }

    function excludeFromDividends(address account, bool value) external onlyOwner {
        require(excludedFromDividends[account] != value);
        excludedFromDividends[account] = value;
        if (value == true) {
            _setBalance(account, 0);
        }
        else {
            _setBalance(account, balanceOf(account));
        }
        emit ExcludeFromDividends(account, value);
    }

    function getAccount(address account) public view returns (address, uint256, uint256, uint256, uint256) {
        AccountInfo memory info;
        info.account = account;
        info.withdrawableDividends = withdrawableDividendOf(account);
        info.totalDividends = accumulativeDividendOf(account);
        info.lastClaimTime = lastClaimTimes[account];
        return (
            info.account,
            info.withdrawableDividends,
            info.totalDividends,
            info.lastClaimTime,
            totalDividendsWithdrawn
        );

    }

    function setBalance(address account, uint256 newBalance) external onlyOwner {
        if (excludedFromDividends[account]) {
            return;
        }
        _setBalance(account, newBalance);
    }

    function processAccount(address payable account) external onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

        if (amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount);
            return true;
        }
        return false;
    }
}
