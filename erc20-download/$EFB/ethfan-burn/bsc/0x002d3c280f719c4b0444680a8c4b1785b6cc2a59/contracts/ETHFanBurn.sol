//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./DividendDistributor.sol";

contract ETHFanBurn is IERC20, Ownable {
    using SafeMath for uint256;

    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public REWARD = 0xB72962568345253f71A18318D67E13A282b187E6;

    string constant _name = "ETHFan Burn";
    string constant _symbol = "$EFB";
    uint8 constant _decimals = 9;

    uint256 _totalSupply = 1000000000000 * (10**_decimals);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isDividendExempt;
    // allowed users to do transactions before trading enable
    mapping(address => bool) isAuthorized;
    mapping(address => bool) isMaxTxExempt;
    mapping(address => bool) isMaxWalletExempt;

    // buy fees
    uint256 public buyRewardFee = 4;
    uint256 public buyMarketingFee = 3;
    uint256 public buyLiquidityFee = 1;
    uint256 public buyBurnFee = 1;
    uint256 public buyStakePoolFee = 0;
    uint256 public buyTotalFees = 9;
    // sell fees
    uint256 public sellRewardFee = 4;
    uint256 public sellMarketingFee = 3;
    uint256 public sellLiquidityFee = 1;
    uint256 public sellBurnFee = 1;
    uint256 public sellStakePoolFee = 0;
    uint256 public sellTotalFees = 9;

    address public marketingFeeReceiver;
    address public stakePoolAddress;

    // swap percentage
    uint256 public rewardSwap = 4;
    uint256 public marketingSwap = 3;
    uint256 public liquiditySwap = 1;
    uint256 public swapForStake = 0;
    uint256 public burnSwap = 1;
    uint256 public totalSwap = 9;

    IUniswapV2Router02 public router;
    address public pair;

    bool public tradingOpen = false;

    DividendDistributor public dividendTracker;

    uint256 distributorGas = 500000;

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);
    event ChangeRewardTracker(address token);
    event IncludeInReward(address holder);

    bool public swapEnabled = true;
    uint256 public swapThreshold = (_totalSupply * 10) / 10000; // 0.01% of supply
    uint256 public maxWalletTokens = (_totalSupply * 500) / 10000; // 0.5% of supply
    uint256 public maxTxAmount = (_totalSupply * 100) / 10000; // 0.5% of supply

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Factory(router.factory()).createPair(
            WBNB,
            address(this)
        );
        _allowances[address(this)][address(router)] = type(uint256).max;

        dividendTracker = new DividendDistributor(address(router), REWARD);

        isFeeExempt[msg.sender] = true;

        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;

        isAuthorized[owner()] = true;
        isMaxTxExempt[owner()] = true;
        isMaxTxExempt[pair] = true;
        isMaxTxExempt[address(this)] = true;

        isMaxWalletExempt[owner()] = true;
        isMaxWalletExempt[pair] = true;
        isMaxWalletExempt[address(this)] = true;

        marketingFeeReceiver = 0x23c37aCE44Ab62dA0ab74A371A6eC59D94cB1c33;
        stakePoolAddress = 0xfc098A2eC7F9fd885C172AFf0CE3a9A0eeAf03E6;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // tracker dashboard functions
    function getHolderDetails(address holder)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getHolderDetails(holder);
    }

    function getLastProcessedIndex() public view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfTokenHolders() public view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function totalDistributedRewards() public view returns (uint256) {
        return dividendTracker.totalDistributedRewards();
    }

    function allowance(address holder, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (!isAuthorized[sender]) {
            require(tradingOpen, "Trading not open yet");
        }
        if (!isMaxTxExempt[sender]) {
            require(amount <= maxTxAmount, "Max Transaction Amount exceed");
        }
        if (!isMaxWalletExempt[recipient]) {
            uint256 balanceAfterTransfer = amount.add(_balances[recipient]);
            require(
                balanceAfterTransfer <= maxWalletTokens,
                "Max Wallet Amount exceed"
            );
        }
        if (shouldSwapBack()) {
            swapBackInBnb();
        }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );

        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, amount, recipient)
            : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        // Dividend tracker
        if (!isDividendExempt[sender]) {
            try dividendTracker.setShare(sender, _balances[sender]) {} catch {}
        }

        if (!isDividendExempt[recipient]) {
            try
                dividendTracker.setShare(recipient, _balances[recipient])
            {} catch {}
        }

        try dividendTracker.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(address sender, address to)
        internal
        view
        returns (bool)
    {
        if (isFeeExempt[sender] || isFeeExempt[to]) {
            return false;
        } else {
            return true;
        }
    }

    function takeFee(
        address sender,
        uint256 amount,
        address to
    ) internal returns (uint256) {
        uint256 feeAmount = 0;
        if (to == pair) {
            feeAmount = amount.mul(sellTotalFees).div(100);
        } else {
            feeAmount = amount.mul(buyTotalFees).div(100);
        }
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            msg.sender != pair &&
            !inSwap &&
            swapEnabled &&
            tradingOpen &&
            _balances[address(this)] >= swapThreshold;
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer((amountBNB * amountPercentage) / 100);
    }

    function updateBuyFees(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity,
        uint256 burn,
        uint256 staking
    ) public onlyOwner {
        buyRewardFee = reward;
        buyMarketingFee = marketing;
        buyLiquidityFee = liquidity;
        buyBurnFee = burn;
        buyStakePoolFee = staking;
        buyTotalFees = reward.add(marketing).add(liquidity).add(burn).add(
            staking
        );
    }

    function updateSellFees(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity,
        uint256 burn,
        uint256 staking
    ) public onlyOwner {
        sellRewardFee = reward;
        sellMarketingFee = marketing;
        sellLiquidityFee = liquidity;
        sellBurnFee = burn;
        sellStakePoolFee = staking;
        sellTotalFees = reward.add(marketing).add(liquidity).add(burn).add(
            staking
        );
    }

    // update swap percentages
    function updateSwapPercentages(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity,
        uint256 burn,
        uint256 staking
    ) public onlyOwner {
        rewardSwap = reward;
        marketingSwap = marketing;
        liquiditySwap = liquidity;
        burnSwap = burn;
        swapForStake = staking;
        totalSwap = reward.add(marketing).add(liquidity).add(burn).add(staking);
    }

    // switch Trading
    function tradingStatus(bool _status) public onlyOwner {
        tradingOpen = _status;
    }

    function whitelistPreSale(address _preSale) public onlyOwner {
        isFeeExempt[_preSale] = true;
        isDividendExempt[_preSale] = true;
        isAuthorized[_preSale] = true;
        isMaxTxExempt[_preSale] = true;
        isMaxWalletExempt[_preSale] = true;
    }

    // manual claim for the greedy humans
    function ___claimRewards(bool tryAll) public {
        dividendTracker.claimDividend();
        if (tryAll) {
            try dividendTracker.process(distributorGas) {} catch {}
        }
    }

    // manually clear the queue
    function claimProcess() public {
        try dividendTracker.process(distributorGas) {} catch {}
    }

    function swapBackInBnb() internal swapping {
        uint256 contractTokenBalance = _balances[address(this)];
        uint256 tokensToLiquidity = contractTokenBalance.mul(liquiditySwap).div(
            totalSwap
        );

        uint256 swapFeeForOtherTokens = rewardSwap.add(swapForStake).add(
            burnSwap
        );
        uint256 tokensToSwapOtherTokens = contractTokenBalance
            .mul(swapFeeForOtherTokens)
            .div(totalSwap);

        // calculate tokens amount to swap
        uint256 tokensToMarketing = contractTokenBalance
            .sub(tokensToLiquidity)
            .sub(tokensToSwapOtherTokens);

        if (tokensToMarketing > 0 && marketingSwap > 0) {
            // swap the tokens
            swapTokensForEth(tokensToMarketing);
            // get swapped bnb amount
            uint256 swappedBnbAmount = address(this).balance;

            (bool marketingSuccess, ) = payable(marketingFeeReceiver).call{
                value: swappedBnbAmount,
                gas: 30000
            }("");
            marketingSuccess = false;
        }

        if (tokensToSwapOtherTokens > 0) {
            swapTokensForTokens(tokensToSwapOtherTokens, REWARD);

            uint256 swappedTokensAmount = IERC20(REWARD).balanceOf(
                address(this)
            );

            uint256 tokensToReward = swappedTokensAmount.mul(rewardSwap).div(
                swapFeeForOtherTokens
            );
            uint256 tokensToBurn = swappedTokensAmount.mul(burnSwap).div(
                swapFeeForOtherTokens
            );
            uint256 tokensToStaking = swappedTokensAmount
                .sub(tokensToReward)
                .sub(tokensToBurn);
            if (tokensToReward > 0 && rewardSwap > 0) {
                // send token to reward
                IERC20(REWARD).transfer(
                    address(dividendTracker),
                    tokensToReward
                );
                try dividendTracker.deposit(tokensToReward) {} catch {}
            }

            if (tokensToBurn > 0 && burnSwap > 0) {
                // send token to reward
                IERC20(REWARD).transfer(address(DEAD), tokensToBurn);
            }

            if (tokensToStaking > 0 && swapForStake > 0) {
                // send token to reward
                IERC20(REWARD).transfer(
                    address(stakePoolAddress),
                    tokensToStaking
                );
            }
        }

        if (tokensToLiquidity > 0) {
            // add liquidity
            swapAndLiquify(tokensToLiquidity);
        }
    }

    function swapAndLiquify(uint256 tokens) private {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit AutoLiquify(newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForTokens(uint256 tokenAmount, address tokenToSwap)
        private
    {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = router.WETH();
        path[2] = tokenToSwap;
        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of tokens
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function setIsDividendExempt(address holder, bool exempt)
        external
        onlyOwner
    {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if (exempt) {
            dividendTracker.setShare(holder, 0);
        } else {
            dividendTracker.setShare(holder, _balances[holder]);
        }
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function setIsMaxTxExempt(address holder, bool exempt) external onlyOwner {
        isMaxTxExempt[holder] = exempt;
    }

    function setIsMaxWalletExempt(address holder, bool exempt)
        external
        onlyOwner
    {
        isMaxWalletExempt[holder] = exempt;
    }

    function addAuthorizedWallets(address holder, bool exempt)
        external
        onlyOwner
    {
        isAuthorized[holder] = exempt;
    }
    function setFeeReceivers(address _marketingFeeReceiver) external onlyOwner {
        marketingFeeReceiver = _marketingFeeReceiver;
    }

    function setStakePoolAddress(address _stakePool) external onlyOwner {
        stakePoolAddress = _stakePool;
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        maxTxAmount = amount * (10**9);
    }

    function setMaxWalletToken(uint256 amount) external onlyOwner {
        maxWalletTokens = amount * (10**9);
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount)
        external
        onlyOwner
    {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external onlyOwner {
        dividendTracker.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000);
        distributorGas = gas;
    }
}
