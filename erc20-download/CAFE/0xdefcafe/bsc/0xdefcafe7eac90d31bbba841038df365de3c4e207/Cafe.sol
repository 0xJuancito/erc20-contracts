//SPDX-License-Identifier: MIT

/*
IDEOLOGY
Imagine Pancakeswap, Pinksale, or another dApp in which decisions and profits are shared with the community with a working multichain. Sounds like the perfect crypto project, right?

Def.Cafe is a fully decentralized, anonymous, and autonomous community project with DAO, BNB rewards and launchpad for enthusiasts who value blockchain ideals and are eager to earn. 
The rules are simple:

1. The owner has no privileges and cannot make major changes to the contract.
2. The society has full control over contract, fees and rewards.
3. Each project decision is made by the society via blockchain voting.
4. Each society member has a right to vote on the project’s future proportional to his current holdings.
5. Each decision is not an empty promise, but a solution tied to the current possibilities of the society via trading volume.
6. Each community member is involved in word-of-mouth marketing.
7. Each community member shares project earnings.

TOKENOMICS
We have the best tokenomics possible for making our plans come to fruition:

- Low 10,000,000 total supply with 9 decimals
- Starting price is $0.0035 per token with micro MCAP
- 98% of the total supply is going to the community. The team has only 2%
- Honest fees. Most tokens have totally inexplicable and unjustified double- or even triple-tax systems. You have to pay a tax on buys, you have to pay a tax on sells, and sometimes you even have to pay tax on transfers from one wallet to another. You are robbed multiple times and driven  to a loss even before the slightest sign of profit has appeared on the horizon! With Def.Cafe society, you have to pay tax only once - when you get your profit.
- 1-year liquidity lock. All added liquidity goes to the zero address
- High MCAP-Liquidity ratio - each $1 of MCAP is supplied by $0.5 in liquidity
- Contract address that no one can confuse with another - 0xdefCafE7eAC90d31BbBA841038DF365DE3c4e207


FEES
- Transfer: 0%
Gradually decreasing after launch buy/sell fees:
- First 10 minutes: 15/30
- After 10 minutes: 0/30
- After 5 days: 0/15

The 15% sell tax goes 3%/6%/6% to Liquidity, Rewards Pool, and Development & Marketing, respectively. The minimum possible sell tax is 5%, and the maximum is 20%. The society will choose taxes once every 10 days via dApp voting.

MILESTONES
Milestones are tied to total trading volume:

- $1m+ - BSCScan, DexTools ADS, active daily marketing campaign
- $5m+ - staking with BNB rewards
- $20m+ - Voting DAO dApp development with ownable society membership. $CAFE and staking contract owners are changed by DAO contract. The society has full control over fees and rewards.
- $50m+ - launchpad/financial/DEX dApp development by society choice. 30% of revenue goes to society members.
- $100m+ - Polygon and Avalanche launch

Together we can do anything. Let's shake up the crypto world!

SOCIALS:
Website https://def.cafe
Telegram https://t.me/DefCafeSociety
Twitter https://twitter.com/DefCafeSociety
Other socials: @DefCafeSociety
*/

pragma solidity ^0.8.7;

import 'Util.sol';

contract Cafe is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _owned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _excluded;
    mapping (address => bool) public _automatedMarketMakerPairs;

    address private _developerWallet = 0xcaFe11111BeE7e3e14bbF6B399aF6a85971F4Ecc;
    address public _rewardsWallet = 0xcAfE22222543F4101d0af8E24e87803378429D2C;
    uint256 private _tSupply = 10000000 * 10**9;

    string private _name = "Def.Cafe";
    string private _symbol = "CAFE";
    uint8 private _decimals = 9;

    uint256 public _Fee = 15;
    uint256 private immutable _liquidityFeePercentage = 20;
    uint256 private immutable _marketingFeePercentage = 40;
    uint256 private immutable _rewardsFeePercentage = 40;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    bool private threeDaysFeePeriodStarted = false;
    
    uint256 private feePeriodStartTime = 0;
    uint256 private feePeriodEndTime = 0;
    uint256 private buyingFeePeriodEndTime = 0;

    uint256 private minTokensToLiquify = 300 * 10**9;
    uint256 private maxTokensToLiquify = 10000 * 10**9;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () {
        _owned[owner()] = _tSupply;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);
        _excluded[owner()] = true;
        _excluded[address(this)] = true;
        
        emit Transfer(address(0), owner(), _tSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _owned[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    function excludeFromFee(address account) public onlyOwner {
        _excluded[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _excluded[account] = false;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    receive() external payable {}
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _excluded[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 contractTokenBalance = balanceOf(address(this));
        
        bool overMinTokenBalance = contractTokenBalance >= minTokensToLiquify;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            !_excluded[from] &&
            !_excluded[to] &&
            !_automatedMarketMakerPairs[from]
        ) {
            if(contractTokenBalance > maxTokensToLiquify) {
                swapAndLiquify(maxTokensToLiquify);
            } else {
                swapAndLiquify(contractTokenBalance);
            } 
        }
        bool isBuyingFee = false;
        bool isEnableFee = false;
        if (_automatedMarketMakerPairs[to] && !_excluded[to] && !_excluded[from]) {
            isEnableFee = true;
        } else if(block.timestamp <= buyingFeePeriodEndTime && _automatedMarketMakerPairs[from] && !_excluded[to] && !_excluded[from]) {
            isEnableFee = true;
            isBuyingFee = true;
        }
        
        (uint256 resultAmount, uint256 fees) = (amount, 0);
       
       if(isEnableFee) {
           (resultAmount, fees) = _getValues(amount, isBuyingFee);
           _transferToken(from, address(this), fees);
       }
       _transferToken(from, to, resultAmount);
    }

    function swapAndLiquify(uint256 tokensToLiquify) private lockTheSwap {
        uint256 singlePart = tokensToLiquify.div(100);
        uint256 rewardsAndDwPart = tokensToLiquify.sub(singlePart.mul(_liquidityFeePercentage));
        uint256 liquidityPart = tokensToLiquify.sub(rewardsAndDwPart);
        uint256 liquidityToLiquify = liquidityPart.div(2);
        uint256 liquidityToAdd = liquidityPart.sub(liquidityToLiquify);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(liquidityToLiquify);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(liquidityToAdd, newBalance);
        swapTokensForEth(rewardsAndDwPart);
        uint256 balanceToSendDW = address(this).balance.div(2);
        uint256 balanceToSendRW = address(this).balance.sub(balanceToSendDW);
        payable(_developerWallet).transfer(balanceToSendDW);
        payable(_rewardsWallet).transfer(balanceToSendRW);

        emit SwapAndLiquify(liquidityToLiquify, newBalance, liquidityToAdd);
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
            address(0),
            block.timestamp
        );
    }

    function _transferToken(address sender, address recipient, uint256 _amount) private {
        _owned[sender] = _owned[sender].sub(_amount);
        _owned[recipient] = _owned[recipient].add(_amount);   
        emit Transfer(sender, recipient, _amount);
    } 

    function _getValues(uint256 _amount, bool buyingTaxPeriod) private view returns (uint256, uint256) {
        uint256 fees = 0;
        if(!buyingTaxPeriod) {
            fees = calculateFee(_amount);
        } else {
            fees = _amount.mul(_Fee).div(10**2);
        }
        uint256 transferAmount = _amount.sub(fees);
        return (transferAmount, fees);
    }
    function getCurrentFee() public view returns(uint256) {
        uint256 resultFee = _Fee;
        if(threeDaysFeePeriodStarted && block.timestamp <= feePeriodEndTime) {
            uint256 daysLeft = (feePeriodEndTime.sub(block.timestamp)).div(1 days);
            uint256 addedFee = daysLeft.mul(5);
            if(addedFee>15) addedFee = 15;
            resultFee = _Fee.add(addedFee);
        }
        return(resultFee);
    }
    function startThreeDaysPeriod() public onlyOwner {
        require(!threeDaysFeePeriodStarted, "Already started.");
        feePeriodStartTime = block.timestamp;
        feePeriodEndTime = feePeriodStartTime.add(4 * 1 days);
        buyingFeePeriodEndTime = block.timestamp.add(10*1 minutes);
        threeDaysFeePeriodStarted = true;
    }
    function calculateFee(uint256 _amount) private view returns (uint256) {
        uint256 currentFee = _Fee;

        if(threeDaysFeePeriodStarted && block.timestamp <= feePeriodEndTime) {
            currentFee = getCurrentFee();
        }
        return _amount.mul(currentFee).div(
            10**2
        );
    }
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        _automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }
    function setMaxTokensToLiquify(uint256 amount) public onlyOwner {
        require(amount <= 30000, "Variable cannot exceed 0,3 percent of the total supply.");
        maxTokensToLiquify = amount * 10**9;
    }
    function setFee(uint256 fee) public onlyOwner {
        require(fee >= 5 && fee <= 20, "Fee cannot exceed 20 percent.");
        require(threeDaysFeePeriodStarted && block.timestamp >= feePeriodEndTime, "Fee cannot be changed during 3 days after launch.");
        _Fee = fee;
    }
    function setDeveloperAddress(address adr) public onlyOwner {
        _developerWallet = adr;
    }
    function setRewardsWallet(address adr) public onlyOwner {
        _rewardsWallet = adr;
    }
}