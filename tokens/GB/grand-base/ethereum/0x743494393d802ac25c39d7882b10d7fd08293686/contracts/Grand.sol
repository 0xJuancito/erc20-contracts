// SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

// import "./openzeppelin-contracts/token/ERC20/ERC20.sol";
// import "./openzeppelin-contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRouter.sol";

contract Grand is ERC20, Ownable {

    IUniswapRouter public router;
    address public pair;

    uint256 constant _totalFullSupply = 50_000_000 * 1e18;
    
    uint256 constant _liquiditySupply         = _totalFullSupply * 10 / 100; // 10% =  5_000_000 * 1e18;
    uint256 public _stakingRewardSupply       = _totalFullSupply * 45 / 100; // 45% = 22_500_000 * 1e18;
    uint256 public _tradingIncentiveSupply    = _totalFullSupply * 20 / 100; // 20% = 10_000_000 * 1e18;
    uint256 public _marketingBudgetSupply     = _totalFullSupply * 10 / 100; // 10% =  5_000_000 * 1e18;
    uint256 public _privateSaleSupply         = _totalFullSupply * 8  / 100; // 8%  =  4_000_000 * 1e18;
    uint256 public _teamTokensSupply          = _totalFullSupply * 7  / 100; // 7%  =  3_500_000 * 1e18;

    uint256 public stakingRewardsMintedAt = 0;
    uint256 public tradingIncentiveMintedAt = 0;
    uint256 public marketingBudgetMintedAt = 0;
    uint256 public privateSaleMintedAt = 0;
    uint256 public teamTokensMintedAt = 0;

    // whitelist max buy amount in whitelist step
    uint256 constant _wlMaxBuyAmount = _liquiditySupply / 100; // 1% of liquidity = 50_000 * 1e18;

    uint256 public maxHoldingAmount =  _liquiditySupply / 50; // 2% of initial liquidity, 0.2% of total supply = 100_000 * 1e18
    
    bool private swapping;
    bool public swapEnabled;
    bool public tradingEnabled;
    
    bool public stakingLaunched;
    bool public tradingIncentiveLaunched;

    uint256 private launchTimestamp;

    address public treasuryWallet;

    uint256 public swapTokensAtAmount;
    uint256 public buyTax;
    uint256 public sellTax;
    uint256[] private taxTimestampSteps;
    uint256[] private buyTaxSteps;
    uint256[] private sellTaxSteps; 

    mapping(address => bool) public whitelisted;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromMaxWallet;
    mapping(address => bool) public automatedMarketMakerPairs;

    address[] public whitelist_users = [
        0x1A69284e302046AeB25017766A79f89A08e01261,
        0x5119757E2c791A6De4F3a5Bf38b9fDbfACbd1068,
        0xAFD644Cd6FaB74C9Ab9444c3E420029D4E6B717A,
        0x85d659fD40f0354A419947cb3baCCC1DDa938e61,
        0xDB1bA7c360a7c42A9C163A133906AC4B86891853,
        0x2c5d7333d81eB0eeC7f1ab437d0Bf18f371e06b9,
        0x4CB64dFa9985634BF5442DA1c421F8D493380dA3,
        0x366391f9C9a66AC4A2cf2a7E7788E6BeF80CDeCC,
        0x3F4373aFdde3D7dE3AC433AcC7De685338c3980e,
        0x220b522979B9F2Ca0F83663fcfF2ee2426aa449C,
        0x6fcDaa9e3ee14540EeA3cFC40Bea16bC61F1c2b8,
        0xEE08323d41cbA6C0b72f8d952da8d364bc1Ea71d,
        0x6e74205481C0A61650951a463b18EdD7BCb51e5a,
        0x10E3D80E50fd146175BCEA8D25C5be0085e2BE59,
        0xFdC4C32ac821eB7137f23aC55e3E10C7280eBf7d,
        0xc210204c50e78251689DabE7091Be4d2320F00AB,
        0x5A7a61FACE3C7Bf578098Ad80Fe7E7c471B4277C,
        0x9d156bc7c8768294510A4A41883d5A4EB15b15E3,
        0x5671B8dadc4B50e253B52330C558C9DA112C4886,
        0x42FeeC5c7e7D3c725864A2716CA357Fa9993CCC0,
        0x3185EF019BA1C04B8d65eDB64c1c34C3eaE52271,
        0x9c15078EbFcC032D00faCbB4fB9829b60C6e26b4,
        0xdbF66aCD1F816E44CeBA22b93cA245155D879392,
        0x5Baa197fFEd76a44E7F22fc6E050e7D99025D201,
        0xBC35D102F498B6ACDa7ceC5168Fb4B19D9255953,
        0x79D06301491f92AA60B58eEc3cfbB9ef2E0Ea4f6,
        0x9053137E530b881Fb47E9abdC881dE266F313a1F,
        0x0d3C00C1Da6d3f7791E7320A7130556eBDd46767,
        0x0A753312Aa7F500fbd8De099B15A2e2761757615,
        0x289213e63B7E827a19Bc48e6cb132f6D2dD89342,
        0x5fa85E6FEa19F73f92E665c1d4A0d20F0467d33E,
        0xDa4e25fC45e82dcDe872c8eaD40a6F012428E1EE,
        0x8Cfa8Dd7BD8a1316f145c52D842C09EaC212F642,
        0xb1F0801cf68aAC49789e4332690fb4B8b44Cde68,
        0x2719F75F3734475a0157e1257C12596B8Ac2D1E5,
        0xc7f91e6650Fe21791B1f8af864eD019B6853294E,
        0xa9C3eB1b8250Daddf039A010b67a089D8384f648,
        0xAB2ccE9850e7Dc9b86e9EBf465F86B06a4329766,
        0x44CDDD49C6098B77108336FC5f10A4CC9037d764,
        0xCA1bbb512759dE1bE41ab739151553AACFB5073C,
        0x5B8aCeDd3D078AA30703AdE6a1ca8caC944aD181,
        0x99F5D9E4B88403Fe3590481198396c910610203A,
        0xC15e8aE9BC6Bdea3bfdD16b3498c5C4Af9baC670,
        0xc746696E0f4488c81FC222d3547CCC0777eb860D,
        0x7978D693892F2A20F5DF40561F1E0C48b90e1D73,
        0x1fC593215253271e3077798D784311F6B95902E1,
        0x03150902655e881D873622020BABF8678183C7A6,
        0xE12A574dc83664784B0a3d4672bF9D6E55B5014e,
        0xbDFbe0F5858477CABec37784fdd0aB86e0E600d1,
        0xA59c43ceEF4c1981432c35921E9b3778Fce79faA
    ];

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    constructor(address _treasury) ERC20("Grand", "$GB") {

        swapEnabled = true;

        router = IUniswapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _pair = IFactory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        pair = _pair;
        _setAutomatedMarketMakerPair(pair, true);
        setSwapTokensAtAmount(40000);

        treasuryWallet = _treasury;

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        excludeFromMaxWallet(address(pair), true);
        excludeFromMaxWallet(address(this), true);
        excludeFromMaxWallet(address(router), true);
        excludeFromMaxWallet(owner(), true);

        taxTimestampSteps.push(30 minutes);
        taxTimestampSteps.push(15 minutes);
        taxTimestampSteps.push(15 minutes);

        buyTaxSteps.push(4000);
        buyTaxSteps.push(3000);
        buyTaxSteps.push(1500);

        sellTaxSteps.push(4000);
        sellTaxSteps.push(3000);
        sellTaxSteps.push(1500);

        buyTax = 500;
        sellTax = 500;

        for (uint i = 0; i < whitelist_users.length; i ++) {
            whitelisted[whitelist_users[i]] = true;
        }

        // initial = liquidity + 30% of marketing budget
        uint256 initialMintAmt = _liquiditySupply + _marketingBudgetSupply * 3 / 10;

        // reduce remained _marketingBudgetSupply
        _marketingBudgetSupply = _marketingBudgetSupply * 7 / 10;
        _mint(msg.sender, initialMintAmt); 
    }

    // only owner
    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    // only owner
    function enableTrading(bool _enable) external onlyOwner {
        require(tradingEnabled != _enable && launchTimestamp > 0, "Already Set");
        tradingEnabled = _enable;
    }
    
    // only owner
    function launch() external onlyOwner {
        launchTimestamp = block.timestamp;
        tradingEnabled = true;
    }

    // only owner
    /// @dev Set new pairs created due to listing in new DEX
    function setAutomatedMarketMakerPair(address newPair, bool value)
        external
        onlyOwner
    {
        _setAutomatedMarketMakerPair(newPair, value);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(
            automatedMarketMakerPairs[newPair] != value,
            "Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[newPair] = value;

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    // only owner
    function setTreasuryWallet(address newWallet) public onlyOwner {
        treasuryWallet = newWallet;
    }
    // only owner
    function setSwapTokensAtAmount(uint256 amount) public onlyOwner {
        swapTokensAtAmount = amount * 10**18;
    }

    function updateMaxHoldingAmount(uint256 newNum) public onlyOwner {
        require(newNum >= 100000, "Cannot set maxHoldingAmount lower than 100k tokens");
        maxHoldingAmount = newNum * 10**18;
    }

    // only owner
    function setBuyTax(uint256 _tax) external onlyOwner {
        require(_tax <= 2000, "Fee must be <= 20%");
        buyTax = _tax;
    }
    // only owner
    function setSellTax(uint256 _tax) external onlyOwner {
        require(_tax <= 2000, "Fee must be <= 20%");
        sellTax = _tax;
    }
    // only owner
    function setTaxSteps(uint256[] calldata _timestamps, uint256[] calldata _buyTaxes, uint256[] calldata _sellTaxes) external onlyOwner {
        taxTimestampSteps = _timestamps;
        buyTaxSteps = _buyTaxes;
        sellTaxSteps = _sellTaxes;
    }
    // only owner
    function blacklist(address user, bool value) external onlyOwner {
        require(blacklisted[user] != value, "Already Set");
        blacklisted[user] = value;
    }
    // only owner
    function whitelist(address user, bool value) external onlyOwner {
        require(whitelisted[user] != value, "Already Set");
        whitelisted[user] = value;
    }
    // only owner
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            isExcludedFromFees[account] != excluded,
            "Account is already the value of 'excluded'"
        );
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeFromMaxWallet(address account, bool excluded)
        public
        onlyOwner
    {
        _isExcludedFromMaxWallet[account] = excluded;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        require(!blacklisted[from] && !blacklisted[to], "Blacklisted");

        if (
            !isExcludedFromFees[from] && !isExcludedFromFees[to] && !swapping
        ) {
            require(tradingEnabled, "Trading not active");
            if (!_isExcludedFromMaxWallet[to]) {
                require(
                    amount + balanceOf(to) <= maxHoldingAmount,
                    "Unable to exceed maxHoldingAmount"
                );
            }
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount && contractTokenBalance > 0;

        if (
            canSwap &&
            !swapping &&
            swapEnabled &&
            automatedMarketMakerPairs[to] &&
            !isExcludedFromFees[from] &&
            !isExcludedFromFees[to]
        ) {
            swapping = true;

            if (sellTax > 0) {
                swapToTreasury(swapTokensAtAmount);
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }

        // if no swap
        if (!automatedMarketMakerPairs[to] && !automatedMarketMakerPairs[from])
            takeFee = false;
        else if (isFirstStepTrade()) {
            // if swap and first step, and if whitelisted user, then no fee
            // buy or sell
            if (whitelisted[to] || whitelisted[from]) {
                takeFee = false;
                // if wl is buying, then check balance
                if (whitelisted[to]) {
                    require(balanceOf(to) + amount <= _wlMaxBuyAmount, "Exceed max buy amount!");
                }
            }
        }

        if (takeFee) {
            uint256 feeAmt;
            if (automatedMarketMakerPairs[to])
                feeAmt = (amount * getSellTax()) / 10000;
            else if (automatedMarketMakerPairs[from])
                feeAmt = (amount * getBuyTax()) / 10000;

            amount = amount - feeAmt;
            super._transfer(from, address(this), feeAmt);
        }
        super._transfer(from, to, amount);
    }

    function swapToTreasury(uint256 tokens) private {
        swapTokensForETH(tokens);

        uint256 EthTaxBalance = address(this).balance;

        // Send ETH to treasury
        uint256 trAmt = EthTaxBalance;

        if (trAmt > 0) {
            (bool success, ) = payable(treasuryWallet).call{value: trAmt}("");
            require(success, "Failed to send ETH to treasury wallet");
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        // router.swapExactTokensForETH(
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function isFirstStepTrade() internal view returns (bool) {
        uint256 curTick = block.timestamp;
        return curTick <= (launchTimestamp + taxTimestampSteps[0]);
    }

    function getSellTax() internal view returns (uint256) {
        uint256 curTick = block.timestamp;
        uint256 i;
        uint256 tick = launchTimestamp;
        for (i = 0; i < taxTimestampSteps.length; i ++) {
            if (curTick <= tick + taxTimestampSteps[i]) return sellTaxSteps[i];
            tick += taxTimestampSteps[i];
        }
        return sellTax;
    }

    function getBuyTax() internal view returns (uint256) {
        uint256 curTick = block.timestamp;
        uint256 i;
        uint256 tick = launchTimestamp;
        for (i = 0; i < taxTimestampSteps.length; i ++) {
            if (curTick <= tick + taxTimestampSteps[i]) return buyTaxSteps[i];
            tick += taxTimestampSteps[i];
        }
        return buyTax;
    }

    // only owner
    function mintMarketingBudget() external onlyOwner {
        require(launchTimestamp > 0, "token is not launched yet");
        require(_marketingBudgetSupply > 0, "no token to mint");

        uint256 curTick = block.timestamp;
        if (marketingBudgetMintedAt == 0) {
            marketingBudgetMintedAt = launchTimestamp;
        }
        if (marketingBudgetMintedAt + 7 days <= curTick) {
            uint256 mintAmount = _totalFullSupply * 1 / 100; // 10% of _marketingBudgetSupply
            // if mintAmount is bigger than _marketingBudgetSupply, then set it to _marketingBudgetSupply
            if (mintAmount > _marketingBudgetSupply) mintAmount = _marketingBudgetSupply;
            // reduce _marketingBudgetSupply by subtrating mintAmount
            _marketingBudgetSupply = _marketingBudgetSupply - mintAmount;

            _mint(msg.sender, mintAmount); 
            marketingBudgetMintedAt = marketingBudgetMintedAt + 7 days;
        }
    }

    // only owner
    function mintPrivateSale() external onlyOwner {
        require(launchTimestamp > 0, "token is not launched yet");
        require(_privateSaleSupply > 0, "no token to mint");

        uint256 curTick = block.timestamp;
        if (privateSaleMintedAt == 0) {
            // at first, 2 days after tge, mint 30%
            if (launchTimestamp + 2 days <= curTick) {
                uint256 mintAmount = (_totalFullSupply * 8 / 100) * 3 / 10; // 30% first
                _mint(msg.sender, mintAmount); 
                privateSaleMintedAt = launchTimestamp + 2 days;
                _privateSaleSupply = _privateSaleSupply - mintAmount;
            }
        } else {
            if (privateSaleMintedAt + 7 days <= curTick) {
                uint256 mintAmount = (_totalFullSupply * 8 / 100) / 10; // 10% of _privateSaleSupply
                // if mintAmount is bigger than _privateSaleSupply, then set it to _privateSaleSupply
                if (mintAmount > _privateSaleSupply) mintAmount = _privateSaleSupply;
                // reduce _privateSaleSupply by subtrating mintAmount
                _privateSaleSupply = _privateSaleSupply - mintAmount;

                _mint(msg.sender, mintAmount); 
                privateSaleMintedAt = privateSaleMintedAt + 7 days;
            }
        }
    }

    // only owner
    function mintTeamTokens() external onlyOwner {
        require(launchTimestamp > 0, "token is not launched yet");
        require(_teamTokensSupply > 0, "no token to mint");
        require(launchTimestamp + 30 days <= block.timestamp, "1 month should past");
        uint256 curTick = block.timestamp;

        if (teamTokensMintedAt == 0) {
            teamTokensMintedAt = launchTimestamp + 30 days;
        }
        if (teamTokensMintedAt + 7 days <= curTick) {
            uint256 mintAmount = (_totalFullSupply * 7 / 100) / 20; // 5% of _teamTokensSupply
            // if mintAmount is bigger than _teamTokensSupply, then set it to _teamTokensSupply
            if (mintAmount > _teamTokensSupply) mintAmount = _teamTokensSupply;
            // reduce _teamTokensSupply by subtrating mintAmount
            _teamTokensSupply = _teamTokensSupply - mintAmount;

            _mint(msg.sender, mintAmount); 
            teamTokensMintedAt = teamTokensMintedAt + 7 days;
        }
    }

    function launchStaking() external onlyOwner {
        stakingLaunched = true;
    }
    function launchTradingIncentive() external onlyOwner {
        tradingIncentiveLaunched = true;
    }

    // only owner
    function mintStakingRewards() external onlyOwner {
        require(launchTimestamp > 0, "token is not launched yet");
        require(_stakingRewardSupply > 0, "no token to mint");
        require(stakingLaunched, "staking is not launched yet");

        uint256 curTick = block.timestamp;
        if (stakingRewardsMintedAt == 0) {
            // at first, mint 30%
            uint256 mintAmount = (_totalFullSupply * 45 / 100) * 3 / 10; // 30% first
            _mint(msg.sender, mintAmount); 
            stakingRewardsMintedAt = curTick;
            _stakingRewardSupply = _stakingRewardSupply - mintAmount;
        } else {
            if (stakingRewardsMintedAt + 7 days <= curTick) {
                uint256 mintAmount = (_totalFullSupply * 45 / 100) / 10; // 10% of _stakingRewardSupply
                // if mintAmount is bigger than _stakingRewardSupply, then set it to _stakingRewardSupply
                if (mintAmount > _stakingRewardSupply) mintAmount = _stakingRewardSupply;
                // reduce _stakingRewardSupply by subtrating mintAmount
                _stakingRewardSupply = _stakingRewardSupply - mintAmount;

                _mint(msg.sender, mintAmount); 
                stakingRewardsMintedAt = stakingRewardsMintedAt + 7 days;
            }
        }
    }

    // only owner
    function mintTradingIncentive() external onlyOwner {
        require(launchTimestamp > 0, "token is not launched yet");
        require(_tradingIncentiveSupply > 0, "no token to mint");
        require(tradingIncentiveLaunched, "trading incentive is not launched yet");

        uint256 curTick = block.timestamp;
        if (tradingIncentiveMintedAt == 0) {
            // at first, mint 30%
            uint256 mintAmount = (_totalFullSupply * 20 / 100) * 3 / 10; // 30% first
            _mint(msg.sender, mintAmount); 
            tradingIncentiveMintedAt = curTick;
            _tradingIncentiveSupply = _tradingIncentiveSupply - mintAmount;
        } else {
            if (tradingIncentiveMintedAt + 7 days <= curTick) {
                uint256 mintAmount = (_totalFullSupply * 20 / 100) / 10; // 10% of _tradingIncentiveSupply
                // if mintAmount is bigger than _tradingIncentiveSupply, then set it to _tradingIncentiveSupply
                if (mintAmount > _tradingIncentiveSupply) mintAmount = _tradingIncentiveSupply;
                // reduce _tradingIncentiveSupply by subtrating mintAmount
                _tradingIncentiveSupply = _tradingIncentiveSupply - mintAmount;

                _mint(msg.sender, mintAmount); 
                tradingIncentiveMintedAt = tradingIncentiveMintedAt + 7 days;
            }
        }
    }

    receive() external payable {}
}