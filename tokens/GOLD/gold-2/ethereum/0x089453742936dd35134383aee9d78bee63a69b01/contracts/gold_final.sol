pragma solidity ^0.8.15;
// SPDX-License-Identifier: Unlicensed

/**

Website: https://hodl.gold
By: ShibaDoge Labs / https://shibadoge.com

 ██████╗  ██████╗ ██╗     ██████╗      ██████╗ ██████╗ ██╗███╗   ██╗
██╔════╝ ██╔═══██╗██║     ██╔══██╗    ██╔════╝██╔═══██╗██║████╗  ██║
██║  ███╗██║   ██║██║     ██║  ██║    ██║     ██║   ██║██║██╔██╗ ██║
██║   ██║██║   ██║██║     ██║  ██║    ██║     ██║   ██║██║██║╚██╗██║
╚██████╔╝╚██████╔╝███████╗██████╔╝    ╚██████╗╚██████╔╝██║██║ ╚████║
 ╚═════╝  ╚═════╝ ╚══════╝╚═════╝      ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝

*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Gold is ERC20, Ownable2Step, ERC20Burnable, ERC20Permit {
    address payable public marketingFeeAddress;
    address payable public societyFeeAddress;

    uint16 constant feeDenominator = 1000;
    uint16 constant maxFeeLimit = 300;

    bool public tradingActive;
    uint256 public maxWallet = 0;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromLimit;

    bool public hasLiquidity;

    uint16 public buyBurnFee = 0;
    uint16 public buyLiquidityFee = 100;
    uint16 public buyMarketingFee = 200;
    uint16 public buySocietyFee = 0;

    uint16 public sellBurnFee = 0;
    uint16 public sellLiquidityFee = 100;
    uint16 public sellMarketingFee = 200;
    uint16 public sellSocietyFee = 0;

    uint16 public transferBurnFee = 0;
    uint16 public transferLiquidityFee = 100;
    uint16 public transferMarketingFee = 200;
    uint16 public transferSocietyFee = 0;

    uint256 public _liquidityTokensToSwap;
    uint256 public _marketingFeeTokensToSwap;
    uint256 public _burnFeeTokens;
    uint256 public _societyFeeTokens;

    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public botWallet;
    address[] public botWallets;

    IUniswapV2Router02 public immutable uniswapRouter;

    address public immutable uniswapPair;

    bool inSwapAndLiquify;
    uint256 swapThreshold = 0;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event SwapThresholdUpdated(uint256 minTokensBeforeSwap);
    event TransferTaxCollected(uint256 amount);
    event BuyTaxCollected(uint256 amount);
    event SellTaxCollected(uint256 amount);
    event SwapAndLiquify(uint256 tokensIntoLiquidity, uint256 ethIntoLiqudity, uint256 marketingEth, uint256 societyEth);

    constructor() ERC20("GOLD", "GOLD") ERC20Permit("Gold") {
        _mint(msg.sender, 21_000_000 * 10 ** decimals());

        marketingFeeAddress = payable(0xeDA0Fd2B2eBc66a89c462E09D28460BD3E9158c2);
        societyFeeAddress   = payable(0xeDA0Fd2B2eBc66a89c462E09D28460BD3E9158c2);

        address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

        uniswapRouter = IUniswapV2Router02(payable(routerAddress));

        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this),
            uniswapRouter.WETH()
        );

        isExcludedFromFee[msg.sender]          = true;
        isExcludedFromFee[address(this)]       = true;
        isExcludedFromFee[marketingFeeAddress] = true;
        isExcludedFromFee[societyFeeAddress]   = true;

        maxWallet = totalSupply() / 200; // 0.5% of supply (105_000)
        swapThreshold = maxWallet / 10; // 10% of max wallet (10_500)

        _approve(msg.sender, routerAddress, type(uint256).max);
        _setAutomatedMarketMakerPair(uniswapPair, true);
        _approve(address(this), address(uniswapRouter), type(uint256).max);
    }

    function increaseRouterAllowance(address routerAddress) external onlyOwner {
        _approve(address(this), routerAddress, type(uint256).max);
    }

    function addBotWallet(address wallet) external onlyOwner {
        require(!botWallet[wallet], "Wallet already added");
        botWallet[wallet] = true;
        botWallets.push(wallet);
    }

    function addBotWalletBulk(address[] memory wallets) external onlyOwner {
        for (uint256 i = 0; i < wallets.length; i++) {
            require(!botWallet[wallets[i]], "Wallet already added");
            botWallet[wallets[i]] = true;
            botWallets.push(wallets[i]);
        }
    }

    function getBotWallets() external view returns (address[] memory) {
        return botWallets;
    }

    function removeBotWallet(address wallet) external onlyOwner {
        require(botWallet[wallet], "Wallet not added");
        botWallet[wallet] = false;
        for (uint256 i = 0; i < botWallets.length; i++) {
            if (botWallets[i] == wallet) {
                botWallets[i] = botWallets[botWallets.length - 1];
                botWallets.pop();
                break;
            }
        }
    }

    function removeBotWalletBulk(address[] memory wallets) external onlyOwner {
        for (uint256 i = 0; i < wallets.length; i++) {
            botWallet[wallets[i]] = false;
        }

        botWallets = new address[](0);
    }

    function unleashTheGold() external onlyOwner {
        tradingActive = true;
    }

    function leashTheGold() external onlyOwner {
        tradingActive = false;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) external onlyOwner {
        require(pair != uniswapPair, "The pair cannot be removed");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;
    }

    function excludeFromLimit(address account) public onlyOwner {
        isExcludedFromLimit[account] = true;
    }

    function includeInLimit(address account) public onlyOwner {
        isExcludedFromLimit[account] = false;
    }

    function updateBuyFee(
        uint16 _buyBurnFee,
        uint16 _buyLiquidityFee,
        uint16 _buyMarketingFee,
        uint16 _buySocietyFee
    ) external onlyOwner {
        buyBurnFee      = _buyBurnFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyMarketingFee = _buyMarketingFee;
        buySocietyFee   = _buySocietyFee;
        require(
            _buyBurnFee +
                _buyLiquidityFee +
                _buyMarketingFee +
                _buySocietyFee <=
                maxFeeLimit,
            "Must keep fees below 30%"
        );
    }

    function updateSellFee(
        uint16 _sellBurnFee,
        uint16 _sellLiquidityFee,
        uint16 _sellMarketingFee,
        uint16 _sellSocietyFee
    ) external onlyOwner {
        sellBurnFee      = _sellBurnFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellMarketingFee = _sellMarketingFee;
        sellSocietyFee   = _sellSocietyFee;
        require(
            _sellBurnFee +
                _sellLiquidityFee +
                _sellMarketingFee +
                _sellSocietyFee <=
                maxFeeLimit,
            "Must keep fees <= 30%"
        );
    }

    function updateTransferFee(
        uint16 _transferBurnFee,
        uint16 _transferLiquidityFee,
        uint16 _transferMarketingFee,
        uint16 _transferSocietyfee
    ) external onlyOwner {
        transferBurnFee      = _transferBurnFee;
        transferLiquidityFee = _transferLiquidityFee;
        transferMarketingFee = _transferMarketingFee;
        transferSocietyFee   = _transferSocietyfee;
        require(
            _transferBurnFee +
                _transferLiquidityFee +
                _transferMarketingFee +
                _transferSocietyfee <=
                maxFeeLimit,
            "Must keep fees <= 30%"
        );
    }

    function updateMarketingFeeAddress(
        address marketingFeeAddress_
    ) external onlyOwner {
        require(marketingFeeAddress_ != address(0), "Can't set 0");
        marketingFeeAddress = payable(marketingFeeAddress_);
    }

    function updateSocietyAddress(
        address societyFeeAddress_
    ) external onlyOwner {
        require(societyFeeAddress_ != address(0), "Can't set 0");
        societyFeeAddress = payable(societyFeeAddress_);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (!tradingActive) {
            require(
                isExcludedFromFee[from] || isExcludedFromFee[to],
                "Trading is not active yet."
            );
        }
        require(!botWallet[from] && !botWallet[to], "Bot wallet");
        checkLiquidity();

        if (
            hasLiquidity && !inSwapAndLiquify && automatedMarketMakerPairs[to]
        ) {
            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance >= swapThreshold) {
                takeFee(swapThreshold);
            } 
        }

        uint256 _burnFee;
        uint256 _liquidityFee;
        uint256 _marketingFee;
        uint256 _societyFee;

        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            if (automatedMarketMakerPairs[from]) {
                // Buy
                _burnFee      = (amount * buyBurnFee)      / feeDenominator;
                _liquidityFee = (amount * buyLiquidityFee) / feeDenominator;
                _marketingFee = (amount * buyMarketingFee) / feeDenominator;
                _societyFee   = (amount * buySocietyFee)   / feeDenominator;

                emit BuyTaxCollected(
                    _burnFee + _liquidityFee + _marketingFee + _societyFee
                );
            } else if (automatedMarketMakerPairs[to]) {
                // Sell
                _burnFee      = (amount * sellBurnFee)      / feeDenominator;
                _liquidityFee = (amount * sellLiquidityFee) / feeDenominator;
                _marketingFee = (amount * sellMarketingFee) / feeDenominator;
                _societyFee   = (amount * sellSocietyFee)   / feeDenominator;

                emit SellTaxCollected(
                    _burnFee + _liquidityFee + _marketingFee + _societyFee
                );
            } else {
                _burnFee      = (amount * transferBurnFee)      / feeDenominator;
                _liquidityFee = (amount * transferLiquidityFee) / feeDenominator;
                _marketingFee = (amount * transferMarketingFee) / feeDenominator;
                _societyFee   = (amount * transferSocietyFee)   / feeDenominator;

                emit TransferTaxCollected(
                    _burnFee + _liquidityFee + _marketingFee + _societyFee
                );
            }

            _handleLimited(
                from,
                to,
                amount - _burnFee - _liquidityFee - _marketingFee - _societyFee
            );
        }

        uint256 _transferAmount = amount -
            _burnFee -
            _liquidityFee -
            _marketingFee -
            _societyFee;
        super._transfer(from, to, _transferAmount);
        uint256 _feeTotal = _burnFee +
            _liquidityFee +
            _marketingFee +
            _societyFee;
        if (_feeTotal > 0) {
            super._transfer(from, address(this), _feeTotal);
            _burnFeeTokens            += _burnFee;
            _liquidityTokensToSwap    += _liquidityFee;
            _marketingFeeTokensToSwap += _marketingFee;
            _societyFeeTokens         += _societyFee;
        }
    }

    function takeFee(uint256 tokens) private lockTheSwap {
        uint256 sellFeeDenominator = sellBurnFee +
            sellLiquidityFee +
            sellMarketingFee +
            sellSocietyFee;

        if (sellFeeDenominator == 0) {
            return;
        }

        uint256 burnFeeTokens            = (tokens * sellBurnFee)      / sellFeeDenominator;
        uint256 liquidityTokensToSwap    = (tokens * sellLiquidityFee) / sellFeeDenominator;            
        uint256 marketingFeeTokensToSwap = (tokens * sellMarketingFee) / sellFeeDenominator;
        uint256 societyFeeTokens         = (tokens * sellSocietyFee)   / sellFeeDenominator;

        uint256 totalTokensTaken = burnFeeTokens +
            liquidityTokensToSwap +
            marketingFeeTokensToSwap +
            societyFeeTokens;

        if (totalTokensTaken == 0 || tokens < totalTokensTaken) {
            return;
        }

        swapAndLiquify(
            burnFeeTokens,
            liquidityTokensToSwap,
            marketingFeeTokensToSwap,
            societyFeeTokens
        );
    }

    function swapAndLiquify(
        uint256 burn,
        uint256 liquidity,
        uint256 marketing,
        uint256 society
    ) internal {
        require(_burnFeeTokens >= burn, "Cannot burn more tokens than allocated to burn.");
        require(_liquidityTokensToSwap >= liquidity, "Cannot swap more tokens than allocated to liquidity.");
        require(_marketingFeeTokensToSwap >= marketing, "Cannot swap more tokens than allocated to marketing.");
        require(_societyFeeTokens >= society, "Cannot swap more tokens than allocated to society.");

        uint256 tokensForLiquidity = liquidity / 2;
        uint256 tokensForSwap = liquidity - tokensForLiquidity;

        uint256 initialETHBalance = address(this).balance;
        uint256 toSwap = tokensForSwap + marketing + society;

        swapTokensForETH(toSwap);

        uint256 ethBalance = address(this).balance - initialETHBalance;

        uint256 ethForLiquidity = (ethBalance * tokensForLiquidity) / toSwap;
        uint256 ethForMarketing = (ethBalance * marketing)          / toSwap;
        uint256 ethForSociety   = (ethBalance * society)            / toSwap;

        if (tokensForLiquidity > 0 && ethForLiquidity > 0) {
            addLiquidity(tokensForLiquidity, ethForLiquidity);
        }

        emit SwapAndLiquify(tokensForLiquidity, ethForLiquidity, ethForMarketing, ethForSociety);

        bool success;

        (success, ) = address(marketingFeeAddress).call{
            value: ethForMarketing,
            gas: 50000
        }("");
        (success, ) = address(societyFeeAddress).call{
            value: ethForSociety,
            gas: 50000
        }("");

        if (burn > 0) {
            _burn(address(this), burn);
        }

        _burnFeeTokens -= burn;
        _liquidityTokensToSwap -= liquidity;
        _marketingFeeTokensToSwap -= marketing;
        _societyFeeTokens -= society;
    }

    function ownerSwap(
        uint256 burn,
        uint256 liquidity,
        uint256 marketing,
        uint256 society
    ) external onlyOwner lockTheSwap {
        swapAndLiquify(burn, liquidity, marketing, society);
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0, 
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}

    function checkLiquidity() internal {
        (uint256 r1, uint256 r2, ) = IUniswapV2Pair(uniswapPair).getReserves();

        hasLiquidity = r1 > 0 && r2 > 0 ? true : false;
    }

    function _handleLimited(
        address from,
        address to,
        uint256 taxedAmount
    ) private {
        if (
            isExcludedFromLimit[from] ||
            isExcludedFromLimit[to] ||
            !hasLiquidity ||
            automatedMarketMakerPairs[to] ||
            inSwapAndLiquify
        ) {
            return;
        }

        require(
            balanceOf(to) + taxedAmount <= maxWallet,
            "Max Wallet Threshold Exceeded."
        );
    }

    function updateMaxWallet(uint256 newMax) external onlyOwner {
        maxWallet = newMax;
    }

    function setSwapThreshold(uint256 newSwapThreshold) external onlyOwner {
        swapThreshold = newSwapThreshold;
        emit SwapThresholdUpdated(newSwapThreshold);
    }

    function rescueEth() external payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function rescueTokens(IERC20 _stuckToken) external onlyOwner {
        SafeERC20.safeTransfer(
            _stuckToken,
            owner(),
            _stuckToken.balanceOf(address(this))
        );
    }
}