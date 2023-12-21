/**
    Sen
    
    Website: https://senecaprotocol.com/
    Twitter: twitter.com/SenecaUSD
    Telegram: t.me/seneca_protocol
    Linktree: https://linktr.ee/senecaprotocol
**/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./token/oft/v1/OFT.sol";
import "./interfaces/UniswapAndSafeMath.sol";

/**
 * @title SEN
 * @author blockchainPhysicst
 * @notice SEN inherits from OFT, which enables SEN to create a Layer Zero bridge to other chains for the SEN token in the future
 * @notice addresses are given mint allowances, which can be used to mint SEN tokens
 */

contract SenTokenOFT is OFT {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    ICamelotRouter public camelotV2Router;
    address public uniswapV2Pair;
    address public camelotV2Pair;
    address public constant deadAddress = address(0xdead);
    
    bool private swapping;

    address public revShareWallet;
    address public treasuryWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;
    bool public blacklistRenounced = false;

    uint256 public buyTotalFees;
    uint256 public buyRevShareFee;
    uint256 public buyLiquidityFee;
    uint256 public buyTreasuryFee;

    uint256 public sellTotalFees;
    uint256 public sellRevShareFee;
    uint256 public sellLiquidityFee;
    uint256 public sellTreasuryFee;

    uint256 public tokensForRevShare;
    uint256 public tokensForLiquidity;
    uint256 public tokensForTreasury;

    /******************/

    // exclude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;
    mapping(address => bool) blacklisted;


    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public isCamelotPair;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    /////////////////ERRORS//////////////////////////////////////////////////||
    error swapAmountError(uint256 amount, uint256 required);               //||
    error SwapAmountOutOfRange(uint256 amount, uint256 min, uint256 max);  //||
    error MaxTransactionAmountTooLow(uint256 amount, uint256 min);         //||
    error PairCannotBeRemoved(address pair, address uniswapV2Pair);        //||
    error MaxWalletAmountTooLow(uint256 amount, uint256 min);              //||
    error TransferFromZeroAddress();                                       //||
    error TransferToZeroAddress();                                         //||
    error TradingNotActive();                                              //||
    error BlacklistRightsRevoked();                                        //||
    error InvalidBlacklistAddress(address addr);                           //||
    error TransferExceedsLimit(uint256 amount, uint256 limit);             //||
    error WalletLimitExceeded(uint256 amount, uint256 limit);              //||
    error SenderBlacklisted(address sender);                               //||
    error ReceiverBlacklisted(address receiver);                           //||
    error InvalidTokenAddress(address token);                              //||
    error SellTransferExceedsLimit(uint256 amount, uint256 limit);         //||
    error SellFeeTooHigh(uint256 fee);                                     //||
    error BuyFeeTooHigh(uint256 fee);                                      //||
    error InvalidLiquidityPoolAddress(address lpAddress);                  //||
    /////////////////////////////////////////////////////////////////////////||

    constructor(address lzEndpoint, address uniRouter, address camelotRouter) OFT('Seneca', 'SEN', lzEndpoint)  {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            uniRouter
        );

        ICamelotRouter _camelotV2Router = ICamelotRouter(
            camelotRouter
        );

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        excludeFromMaxTransaction(address(_camelotV2Router), true);
        uniswapV2Router = _uniswapV2Router;
        camelotV2Router = _camelotV2Router;

        uint256 _buyRevShareFee = 2;
        uint256 _buyLiquidityFee = 0;
        uint256 _buyTreasuryFee = 1;

        uint256 _sellRevShareFee = 2;
        uint256 _sellLiquidityFee = 0;
        uint256 _sellTreasuryFee = 1;

        uint256 totalSupply = 100_000_000 * 1e18;

        maxTransactionAmount = 1_000_000 * 1e18; // 1%
        maxWallet = 1_000_000 * 1e18; // 1% 
        swapTokensAtAmount = (totalSupply * 1) / 100000;

        buyRevShareFee = _buyRevShareFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyTreasuryFee = _buyTreasuryFee;
        buyTotalFees = buyRevShareFee + buyLiquidityFee + buyTreasuryFee;

        sellRevShareFee = _sellRevShareFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTreasuryFee = _sellTreasuryFee;
        sellTotalFees = sellRevShareFee + sellLiquidityFee + sellTreasuryFee;

        revShareWallet = address(0x4d6fd0D56800C94b6De102049750BD45A341878f); // set as revShare wallet
        treasuryWallet = address(0xccaB15D3C6e1DB9389135FDb8e19b25896968774); // set as Treasury wallet

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        if (block.chainid == 42161) {
            _mint(msg.sender, totalSupply);
        }
    }

    receive() external payable {}


    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool) {

    uint256 minAmount = (totalSupply() * 1) / 100000; 
    uint256 maxAmount = (totalSupply() * 5) / 1000;

    if (newAmount < minAmount || newAmount > maxAmount) {
        revert SwapAmountOutOfRange(newAmount, minAmount, maxAmount); 
    }

    swapTokensAtAmount = newAmount;

    return true;
    }
    
    function updateMaxTxnAmount(uint256 newNum) external onlyOwner {

    uint256 minAmount = ((totalSupply() * 5) / 1000) / 1e18;

    if (newNum < minAmount) {
        revert MaxTransactionAmountTooLow(newNum, minAmount);
    }

    maxTransactionAmount = newNum * (10**18);
    }

    function updateMaxWalletAmount(uint256 newNum) external onlyOwner {

    uint256 minAmount = ((totalSupply() * 10) / 1000) / 1e18;  

    if (newNum < minAmount) {
        revert MaxWalletAmountTooLow(newNum, minAmount);
    }

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
    uint256 _TreasuryFee
    ) external onlyOwner {
    buyRevShareFee = _revShareFee;
    buyLiquidityFee = _liquidityFee;
    buyTreasuryFee = _TreasuryFee;
    uint256 totalFees = _revShareFee + _liquidityFee + _TreasuryFee;
    if (totalFees > 5) {
        revert BuyFeeTooHigh(totalFees);
    }
    buyTotalFees = totalFees;
    }

    function updateSellFees(
    uint256 _revShareFee, 
    uint256 _liquidityFee,
    uint256 _TreasuryFee  
    ) external onlyOwner {

    sellRevShareFee = _revShareFee;
    sellLiquidityFee = _liquidityFee;
    sellTreasuryFee = _TreasuryFee;
    uint256 totalFees = _revShareFee + _liquidityFee + _TreasuryFee;
    if (totalFees > 5) {
        revert SellFeeTooHigh(totalFees);
    }
    sellTotalFees = totalFees; 
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value, bool isCamelotType) 
    external onlyOwner 
    {

    if (pair == uniswapV2Pair) {
        revert PairCannotBeRemoved(pair, uniswapV2Pair);
    }

    if (pair == camelotV2Pair) {
        revert PairCannotBeRemoved(pair, camelotV2Pair);
    }

    _setAutomatedMarketMakerPair(pair, value);

    if(isCamelotType){
        isCamelotPair[pair] = true;
    } else {
        isCamelotPair[pair] = false;
    }
    }

    function setUniswapV2Pair(address pair)
    external onlyOwner 
    {
        uniswapV2Pair = pair;
        excludeFromMaxTransaction(pair, true);
        _setAutomatedMarketMakerPair(pair, true);
        isCamelotPair[pair] = false;
    }

    function setCamelotV2Pair(address pair) external onlyOwner {
        camelotV2Pair = pair;
        excludeFromMaxTransaction(pair, true);
        _setAutomatedMarketMakerPair(pair, true);
        isCamelotPair[pair] = true;
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateRevShareWallet(address newRevShareWallet) external onlyOwner {
        revShareWallet = newRevShareWallet;
    }

    function updateTreasuryWallet(address newWallet) external onlyOwner {
        treasuryWallet = newWallet;
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
        require(!blacklisted[from],"Sender blacklisted");
        require(!blacklisted[to],"Receiver blacklisted");
        bool checkPairSource = false;

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

        if(isCamelotPair[from] || isCamelotPair[to]) {
            checkPairSource = true;
        } else {
            checkPairSource = false;
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

            swapBack(checkPairSource);

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
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = amount.mul(sellTotalFees).div(100);
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForTreasury += (fees * sellTreasuryFee) / sellTotalFees;
                tokensForRevShare += (fees * sellRevShareFee) / sellTotalFees;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = amount.mul(buyTotalFees).div(100);
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForTreasury += (fees * buyTreasuryFee) / buyTotalFees;
                tokensForRevShare += (fees * buyRevShareFee) / buyTotalFees;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount, bool camelotSource) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        
        if (block.chainid == 42161 && camelotSource) {
            camelotV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                address(this),
                block.timestamp
            );
        } else if (block.chainid == 42161 && !camelotSource) {
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        } else {
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
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

    function swapBack(bool sourcePairIsCamelot) private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity +
            tokensForRevShare +
            tokensForTreasury;
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

        swapTokensForEth(amountToSwapForETH, sourcePairIsCamelot);

        uint256 ethBalance = address(this).balance.sub(initialETHBalance);

        uint256 ethForRevShare = ethBalance.mul(tokensForRevShare).div(totalTokensToSwap - (tokensForLiquidity / 2));
        
        uint256 ethForTreasury = ethBalance.mul(tokensForTreasury).div(totalTokensToSwap - (tokensForLiquidity / 2));

        uint256 ethForLiquidity = ethBalance - ethForRevShare - ethForTreasury;

        tokensForLiquidity = 0;
        tokensForRevShare = 0;
        tokensForTreasury = 0;

        (success, ) = address(treasuryWallet).call{value: ethForTreasury}("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
        }

        (success, ) = address(revShareWallet).call{value: address(this).balance}("");
    }

    function withdrawStuckSen() external onlyOwner {
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

    // @dev unblacklist address; not affected by blacklistRenounced incase team wants to unblacklist v3 pools down the road
    function unblacklist(address _addr) public onlyOwner {
        blacklisted[_addr] = false;
    }

    function updateUniswapRouter(IUniswapV2Router02 newUniRouter) public onlyOwner {
        uniswapV2Router = newUniRouter;
    }

    function updateCamelotRouter(ICamelotRouter newCamelotRouter) public onlyOwner {
        camelotV2Router = newCamelotRouter;
    }

}