// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;


import "./interface/IUniswapV2Router.sol";
import "./interface/IUniswapFactory.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AstroCash is Ownable, ERC20Burnable {
    using SafeMath for uint256;

    IUniswapV2Router public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;
    bool public swapAndLiquifyEnabled = true;

    address payable public marketingWalletAddress = payable(address(0));
    address payable public developmentWalletAddress = payable(address(0));
    address payable public projectWalletAddress = payable(address(0));

    uint256 public swapTokensAtAmount = 10000 * (10**decimals());
    uint256 public maxTxAmount = 1000000 * (10**decimals());
    uint256 public maxBuyAmount = 1000000 * (10**decimals());
    uint256 public maxSaleAmount = 1000000 * (10**decimals());

    uint256[] public liquidityFee;
    uint256[] public projectFee;
    uint256[] public marketingFee;
    uint256[] public developmentFee;
    uint256[] public burnFee;

    uint256 private tokenToSwap;
    uint256 private tokenToMarketing;
    uint256 private tokenToDevelopment;
    uint256 private tokenToProject;
    uint256 private tokenToLiquidity;

    uint256 public liquidityFeeTotal;
    uint256 public projectFeeTotal;
    uint256 public marketingFeeTotal;
    uint256 public developmentFeeTotal;

    uint256 public immutable maxIndividualFee; // Ensures security for investors so that a 99% rate is not possible
    uint256 public immutable minIndividualLimitTx; //  Ensures security for investors so that a 0 linit tx is not possible

    address private _lpDestination;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public isExcludedFromAmountLimitToken;
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    constructor(
        string memory token_name,
        string memory short_symbol,
        uint256 token_totalSupply,
        uint256 max_individual_fee,
        uint256 min_individual_limit_tx
    ) ERC20(token_name, short_symbol) {
        _mint(msg.sender, token_totalSupply * 10**decimals());

        _lpDestination = owner();

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        marketingWalletAddress = payable(owner());
        developmentWalletAddress = payable(owner());
        projectWalletAddress = payable(owner());

        // Set default fees
        liquidityFee.push(300);
        liquidityFee.push(300);
        liquidityFee.push(300);

        projectFee.push(300);
        projectFee.push(300);
        projectFee.push(300);

        marketingFee.push(300);
        marketingFee.push(300);
        marketingFee.push(300);

        developmentFee.push(300);
        developmentFee.push(300);
        developmentFee.push(300);

        burnFee.push(0);
        burnFee.push(0);
        burnFee.push(0);

        // One time change / immutable var / investor protection
        maxIndividualFee = max_individual_fee;
        minIndividualLimitTx = min_individual_limit_tx;
    }

    receive() external payable {}

    /**
     * Set the initial router used to generate liquidity
     **/
    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router(newAddress);

        uniswapV2Pair = IUniswapFactory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);

        _approve(address(this), address(uniswapV2Router), totalSupply());
    }

    /**
     * Update destination for new lp, avoid safemoon security
     **/
    function setLpDestination(address newLpOwner) external onlyOwner {
        _lpDestination = newLpOwner;
    }

    /**
     *  Exclude address from fees
     **/
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    /**
     * Exclude address from tx limits
     **/
    function excludeFromLimitAmount(address account, bool excluded)
        public
        onlyOwner
    {
        require(
            isExcludedFromAmountLimitToken[account] != excluded,
            "Account is already the value of 'excluded'"
        );
        isExcludedFromAmountLimitToken[account] = excluded;
    }

    /**
     * Exclude multiple accounts from fees
     **/
    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    /**
     * Set marketing wallet
     **/
    function setMarketingWallet(address payable wallet) external onlyOwner {
        require(wallet != address(0), "zero-address not allowed");
        marketingWalletAddress = wallet;
    }

    /**
     * Set devs wallet
     **/
    function setDevelopmentWallet(address payable wallet) external onlyOwner {
        require(wallet != address(0), "zero-address not allowed");
        developmentWalletAddress = wallet;
    }

    /**
     * Set project wallet
     **/
    function setProjectWallet(address payable wallet) external onlyOwner {
        require(wallet != address(0), "zero-address not allowed");
        projectWalletAddress = wallet;
    }

    /**
     * Set burn fee: Base 10000, ex.: 1.5% = 150
     **/
    function setBurnFee(
        uint256 buy,
        uint256 sell,
        uint256 p2p
    ) external onlyOwner {
        require(
            buy <= maxIndividualFee &&
                sell <= maxIndividualFee &&
                p2p <= maxIndividualFee,
            "You must respect the maximum allowed fee"
        );
        burnFee[0] = buy;
        burnFee[1] = sell;
        burnFee[2] = p2p;
    }

    /**
     * Set liquidity fee: Base 10000, ex.: 1.5% = 150
     **/
    function setLiquidityFee(
        uint256 buy,
        uint256 sell,
        uint256 p2p
    ) external onlyOwner {
        require(
            buy <= maxIndividualFee &&
                sell <= maxIndividualFee &&
                p2p <= maxIndividualFee,
            "You must respect the maximum allowed fee"
        );
        liquidityFee[0] = buy;
        liquidityFee[1] = sell;
        liquidityFee[2] = p2p;
    }

    /**
     * Set Project fee: Base 10000, ex.: 1.5% = 150
     **/
    function setProjectFee(
        uint256 buy,
        uint256 sell,
        uint256 p2p
    ) external onlyOwner {
        require(
            buy <= maxIndividualFee &&
                sell <= maxIndividualFee &&
                p2p <= maxIndividualFee,
            "You must respect the maximum allowed fee"
        );
        projectFee[0] = buy;
        projectFee[1] = sell;
        projectFee[2] = p2p;
    }

    /**
     *  Set Marketing fee: Base 10000, ex.: 1.5% = 150
     **/
    function setMarketingFee(
        uint256 buy,
        uint256 sell,
        uint256 p2p
    ) external onlyOwner {
        require(
            buy <= maxIndividualFee &&
                sell <= maxIndividualFee &&
                p2p <= maxIndividualFee,
            "You must respect the maximum allowed fee"
        );
        marketingFee[0] = buy;
        marketingFee[1] = sell;
        marketingFee[2] = p2p;
    }

    /**
     * Set Dev fee: Base 10000, ex.: 1.5% = 150
     **/
    function setDevelopmentFee(
        uint256 buy,
        uint256 sell,
        uint256 p2p
    ) external onlyOwner {
        require(
            buy <= maxIndividualFee &&
                sell <= maxIndividualFee &&
                p2p <= maxIndividualFee,
            "You must respect the maximum allowed fee"
        );
        developmentFee[0] = buy;
        developmentFee[1] = sell;
        developmentFee[2] = p2p;
    }

    /**
     *  Set new liquidity pair
     **/
    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != uniswapV2Pair,
            "The PanCakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );
        _setAutomatedMarketMakerPair(pair, value);
    }

    /**
     * Internal function to set liquidity pair
     **/
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    /**
     * Check address for exclude rule
     **/
    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    /**
     * Controls whether charges will be transformed into liquidity or disabled
     **/
    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        swapAndLiquifyEnabled = enabled;
    }

    /**
     * Set max tx amount
     **/
    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(
            amount <= totalSupply() &&
                amount >= totalSupply().mul(minIndividualLimitTx).div(10000),
            "Limit needs to be between the individual minimum and the total supply"
        );

        maxTxAmount = amount;
    }

    /**
     * Set max tx sale amount
     **/
    function setSaleTxAmount(uint256 amount) external onlyOwner {
        require(
            amount <= totalSupply() &&
                amount >= totalSupply().mul(minIndividualLimitTx).div(10000),
            "Limit needs to be between the individual minimum and the total supply"
        );
        maxSaleAmount = amount;
    }

    /**
     * Set max tx buy amount
     **/
    function setBuyTxAmount(uint256 amount) external onlyOwner {
        require(
            amount <= totalSupply() &&
                amount >= totalSupply().mul(minIndividualLimitTx).div(10000),
            "Limit needs to be between the individual minimum and the total supply"
        );
        maxBuyAmount = amount;
    }

    /**
     * Determines how many tokens must be accumulated as a minimum before swapping into liquidity
     **/
    function setSwapTokensAmount(uint256 amount) public onlyOwner {
        require(
            amount <= totalSupply(),
            "Amount cannot be over the total supply."
        );
        swapTokensAtAmount = amount;
    }

    /**
     * BEP20 main transfer method, all fee logic, and limits are contained here
     **/
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // Total transfer allowance per transaction
        if (
            from != owner() &&
            to != owner() &&
            !isExcludedFromAmountLimitToken[from] &&
            !isExcludedFromAmountLimitToken[to]
        ) {
            require(
                amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        // Total sales limit per tx
        if (
            !automatedMarketMakerPairs[from] &&
            automatedMarketMakerPairs[to] &&
            from != owner() &&
            to != owner() &&
            !isExcludedFromAmountLimitToken[from] &&
            !isExcludedFromAmountLimitToken[to]
        ) {
            require(
                amount <= maxSaleAmount,
                "Transfer amount exceeds the maxSaleAmount"
            );
        }

        // Total buy limit per tx
        if (
            automatedMarketMakerPairs[from] &&
            to != owner() &&
            !isExcludedFromAmountLimitToken[from] &&
            !isExcludedFromAmountLimitToken[to]
        ) {
            require(
                amount <= maxBuyAmount,
                "Transfer amount exceeds the maxBuyAmount"
            );
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= maxTxAmount) {
            contractTokenBalance = maxTxAmount;
        }

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            !swapping &&
            automatedMarketMakerPairs[to] &&
            swapAndLiquifyEnabled
        ) {
            swapping = true;
            tokenToMarketing = marketingFeeTotal;
            tokenToDevelopment = developmentFeeTotal;
            tokenToProject = projectFeeTotal;
            tokenToLiquidity = liquidityFeeTotal;

            // When we send liquidity we sell half of the tokens and the other half is used for addition in the liquidity pair.
            uint256 halfTokenToLiquidity = liquidityFeeTotal > 0
                ? liquidityFeeTotal.div(2)
                : 0;

            // Stores the total tokens that will be sold, to generate the share of each fee later.
            tokenToSwap = tokenToMarketing
                .add(tokenToDevelopment)
                .add(tokenToProject)
                .add(halfTokenToLiquidity);

            uint256 tokenToSwapPlusLiq = tokenToSwap.add(halfTokenToLiquidity);
            // We sell in smaller tranches determined by the variable swapTokensAtAmount, we need to know what % liquidity of this total is to be sold.
            uint256 rateLiqFee = halfTokenToLiquidity.mul(10000).div(
                tokenToSwapPlusLiq
            );
            uint256 initialBalance = address(this).balance;
            uint256 swapTokensAtAmountSubLiq = swapTokensAtAmount.sub( // Found liquidity share from swapTokensAtAmount
                swapTokensAtAmount.mul(rateLiqFee).div(10000)
            );
            // Exchange tokens for BNB
            swapTokensForBNB(swapTokensAtAmountSubLiq);
            uint256 newBalance = address(this).balance.sub(initialBalance);

            // Determines the corresponding total of each fee in the new balance accrued in BNB
            uint256 marketingPart = newBalance.mul(tokenToMarketing).div(
                tokenToSwap
            );
            uint256 developmentPart = newBalance.mul(tokenToDevelopment).div(
                tokenToSwap
            );
            uint256 projectPart = newBalance.mul(tokenToProject).div(
                tokenToSwap
            );

            // What remains will be used for liquidity
            uint256 liquidityPart = newBalance
                .sub(marketingPart)
                .sub(developmentPart)
                .sub(projectPart);

            // Adjusts the total used of each token per fee in this liquidity transaction
            if (marketingPart > 0) {
                payable(marketingWalletAddress).transfer(marketingPart);
                marketingFeeTotal = marketingFeeTotal.sub(
                    swapTokensAtAmount.mul(tokenToMarketing).div(
                        tokenToSwapPlusLiq
                    )
                );
            }

            if (developmentPart > 0) {
                payable(developmentWalletAddress).transfer(developmentPart);
                developmentFeeTotal = developmentFeeTotal.sub(
                    swapTokensAtAmount.mul(tokenToDevelopment).div(
                        tokenToSwapPlusLiq
                    )
                );
            }

            if (projectPart > 0) {
                payable(projectWalletAddress).transfer(projectPart);
                projectFeeTotal = projectFeeTotal.sub(
                    swapTokensAtAmount.mul(tokenToProject).div(
                        tokenToSwapPlusLiq
                    )
                );
            }

            // Add liquidity to pancakeswap
            if (liquidityPart > 0) {
                addLiquidity(
                    halfTokenToLiquidity,
                    liquidityPart,
                    _lpDestination
                );

                liquidityFeeTotal = liquidityFeeTotal.sub(
                    swapTokensAtAmount.mul(tokenToLiquidity).div(
                        tokenToSwapPlusLiq
                    )
                );
            }
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        // Collects the tokens/fees that will be transformed into liquidity at the correct time.
        if (takeFee) {
            (
                uint256 transferToContractFee,
                uint256 burnFeeTx,
                uint256 transferedToWalletFee
            ) = collectFee(
                    from,
                    amount,
                    automatedMarketMakerPairs[to],
                    !automatedMarketMakerPairs[from] &&
                        !automatedMarketMakerPairs[to]
                );

            if (transferToContractFee > 0)
                super._transfer(from, address(this), transferToContractFee);
            if (burnFeeTx > 0) _burn(from, burnFeeTx);

            amount = amount.sub(transferToContractFee).sub(burnFeeTx).sub(
                transferedToWalletFee
            );
        }

        super._transfer(from, to, amount);
    }

    /**
     * Calculates the fee amounts that will be held in the contract for later generation of liquidity and distribution
     **/
    function collectFee(
        address from,
        uint256 amount,
        bool sell,
        bool p2p
    )
        private
        returns (
            uint256 transferToContractFee,
            uint256 burnFeeTx,
            uint256 transferedToWalletFee
        )
    {
        uint256 liquifyFeeNew = amount
            .mul(
                p2p ? liquidityFee[2] : sell ? liquidityFee[1] : liquidityFee[0]
            )
            .div(10000);

        liquidityFeeTotal = liquidityFeeTotal.add(liquifyFeeNew);

        uint256 projectFeeNew = amount
            .mul(p2p ? projectFee[2] : sell ? projectFee[1] : projectFee[0])
            .div(10000);

        if (swapAndLiquifyEnabled)
            projectFeeTotal = projectFeeTotal.add(projectFeeNew);
        else if (projectFeeNew > 0)
            super._transfer(from, projectWalletAddress, projectFeeNew);

        uint256 marketingFeeNew = amount
            .mul(
                p2p ? marketingFee[2] : sell ? marketingFee[1] : marketingFee[0]
            )
            .div(10000);

        if (swapAndLiquifyEnabled)
            marketingFeeTotal = marketingFeeTotal.add(marketingFeeNew);
        else if (marketingFeeNew > 0)
            super._transfer(from, marketingWalletAddress, marketingFeeNew);

        uint256 developmentFeeNew = amount
            .mul(
                p2p ? developmentFee[2] : sell
                    ? developmentFee[1]
                    : developmentFee[0]
            )
            .div(10000);

        if (swapAndLiquifyEnabled)
            developmentFeeTotal = developmentFeeTotal.add(developmentFeeNew);
        else if (developmentFeeNew > 0)
            super._transfer(from, developmentWalletAddress, developmentFeeNew);

        burnFeeTx = amount
            .mul(p2p ? burnFee[2] : sell ? burnFee[1] : burnFee[0])
            .div(10000);

        transferToContractFee = swapAndLiquifyEnabled
            ? liquifyFeeNew.add(projectFeeNew).add(marketingFeeNew).add(
                developmentFeeNew
            )
            : liquifyFeeNew;

        transferedToWalletFee = !swapAndLiquifyEnabled
            ? projectFeeNew.add(marketingFeeNew).add(developmentFeeNew)
            : 0;
    }

    /**
     * Swaps contract tokens into BNB
     **/
    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     *  Adds liquidity to DEX
     **/
    function addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        address account
    ) internal {
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage
            0, // slippage
            account,
            block.timestamp
        );
    }

    /**
     * Send any remaining BNB that is in the contract.
     **/
    function sendDustBNB(address payable _recipient) public onlyOwner {
        _recipient.transfer(address(this).balance);
    }
}
