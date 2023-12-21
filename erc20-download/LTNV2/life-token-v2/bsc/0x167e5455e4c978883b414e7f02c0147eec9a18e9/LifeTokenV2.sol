// SPDX-License-Identifier: MIT

/*
     (               )
     )\ )  *   )  ( /(             )
    (()/(` )  /(  )\()) (   (   ( /(
     /(_))( )(_))((_)\  )\  )\  )(_))
    (_)) (_(_())  _((_)((_)((_)((_)
    | |  |_   _| | \| |\ \ / / |_  )
    | |__  | |   | .` | \ V /   / /
    |____| |_|   |_|\_|  \_/   /___|

    Please check out our WhitePaper over at https://www.thelifetoken.com/
    to get an overview of our contract!
*/

pragma solidity ^0.8.7;

import "./IERC20.sol";

import "./ERC20.sol";

import "./Address.sol";

import "./Context.sol";

import "./Ownable.sol";

import "./PancakeFactory.sol";

import "./PancakeRouter.sol";

import "./LifeTokenDividends.sol";

contract LifeTokenV2 is Context, IERC20, Ownable {
    using Address for address;

    enum TransferType {
        Default,
        Buy,
        Sell,
        Excluded
    }

    struct IsExcluded {
        bool fromFee;
    }

    address payable public _charityAddress =
        payable(0x52AFe67Dd36Bc0F2fBE4efAE2233B592c75e7538);
    address payable public _marketingAddress =
        payable(0x7F329F7575FDf8b01eb8B989d7754728dd1647A9);
    address payable public _buyBackAddress =
        payable(0xC4955fb6E39f9B5e6AaCA059991C46c92A7073f0);
    address public immutable _burnAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint128) private _balances;
    mapping(address => IsExcluded) private _isExcluded;
    LifeTokenDividends public _dividends;

    TransferType private _transferType = TransferType.Default;

    bool private _lockSwap;
    uint8 private _contractToggles;
    uint24 private constant DENOMINATOR = 100000;
    uint64 private _creationDate = uint64(block.timestamp);
    uint128 private _totalSupply = (10**13) * (10**18); /// 10 Trillion

    bytes32 private _contractTrackerZero;
    bytes32 private _contractTrackerOne;
    bytes32 private _contractTrackerTwo;
    bytes32 private _contractTrackerThree;

    IPancakeRouter02 public  PancakeRouter;
    address public  PancakePair;

    event UpdateDividendsContract(
        address indexed oldAddress,
        address indexed newAddress
    );
    event BuybackAndBurnTokens(uint256 bnbSwapped, uint256 tokensBurned);
    event AddLiquidity(uint256 tokensIn, uint256 bnbIn, address path);
    event SwapTokensForBNB(uint128 tokensSold, uint128 bnbReceived);
    event SendToWallet(
        string indexed wallet,
        address indexed walletAddress,
        uint256 bnbForLP
    );
    event TrackerUpdated(
        bytes32 indexed tracker,
        uint128 oldValue,
        uint128 newValue,
        bool indexed added
    );
    event ProcessingGasAmountUpdated(uint256 oldValue, uint256 newValue);
    event ProcessingDividendsError(address msgSender);
    event ProcessedDividends(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    modifier LockSwap() {
        _lockSwap = true;
        _;
        _lockSwap = false;
    }

    constructor() {
        _dividends = new LifeTokenDividends();

        _dividends.excludeFromDividends(address(_dividends));
        _dividends.excludeFromDividends(address(this));
        _dividends.excludeFromDividends(_charityAddress);
        _dividends.excludeFromDividends(_marketingAddress);
        _dividends.excludeFromDividends(_buyBackAddress);
        _dividends.excludeFromDividends(owner());
        _dividends.excludeFromDividends(_burnAddress);

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E // (mainnet)
            //0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 // (testnet router)
        );
        address pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), pancakeRouter.WETH());
        PancakeRouter = pancakeRouter;
        PancakePair = pancakePair;
        _dividends.excludeFromDividends(PancakePair);
        setTracker(3, 0, 500000, false); /// Set gas for processing to 500,000 wei
        setTracker(3, 1, 500000000 * (10**18), false); /// Set minimum before sell to 500 million tokens

        _isExcluded[owner()].fromFee = true;
        _isExcluded[address(this)].fromFee = true;
        _balances[owner()] = _totalSupply;
        _approve(address(this), address(PancakeRouter), _totalSupply);
        emit Transfer(address(0), owner(), _balances[owner()]);
    }

    receive() external payable {}

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        _verify(_msgSender(), to);
        _transfer(_msgSender(), to, uint128(amount));
        return true;
    }

    
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, uint128(amount));
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
        _approve(sender, _msgSender(), currentAllowance - amount);
    }

        return true;
    }

    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
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

    function setNewDividendsContract(address newAddress) external onlyOwner {
        require(
            newAddress != address(_dividends),
            "Dividends Contract address must not be the same"
        );

        LifeTokenDividends newDividendsContract = LifeTokenDividends(
            payable(newAddress)
        );

        require(
            newDividendsContract.owner() == address(this),
            "The New Dividends Contract must be owned by this contract"
        );

        newDividendsContract.excludeFromDividends(
            address(newDividendsContract)
        );
        newDividendsContract.excludeFromDividends(address(this));
        newDividendsContract.excludeFromDividends(owner());
        newDividendsContract.excludeFromDividends(address(PancakeRouter));

        emit UpdateDividendsContract(address(_dividends), newAddress);

        _dividends = newDividendsContract;
    }

    /// Token Amount for trigger selling tokens
    function setGasForProcessingDividends(uint128 gasAmount)
        external
        onlyOwner
    {
        require(
            gasAmount >= 200000 && gasAmount <= 1000000,
            "Gas for processing must be between 200,000 and 1,000,000"
        );
        uint128 oldGasAmount = _getTracker(3, 0);
        require(
            gasAmount != oldGasAmount,
            "Gas amount already set to that value"
        );
        emit ProcessingGasAmountUpdated(oldGasAmount, gasAmount);
        setTracker(3, 0, gasAmount, false);
    }

    /// Token Amount for trigger selling tokens (min required 1)
    function setMinimumTokensBeforeSell(uint128 tokenAmount)
        external
        onlyOwner
    {
        require(tokenAmount >= 1, "Token amount must be at least 1");

        setTracker(3, 1, tokenAmount * (10**18), false);
    }

    function setCharityAddress(address newAddress) external onlyOwner {
        _charityAddress = payable(newAddress);
    }

    function setMarketingAddress(address newAddress) external onlyOwner {
        _marketingAddress = payable(newAddress);
    }
    
    function setBuyBackAddress(address newAddress) external onlyOwner {
        _buyBackAddress = payable(newAddress);
    }

    function burn(uint128 amount) external {
        _verify(_msgSender(), _burnAddress);
        require(
            _balances[_msgSender()] >= amount,
            "Balance must be greater than amount"
        );
        _burn(_msgSender(), amount);
    }

    function excludeFromFee(address account) external onlyOwner {
        require(
            !_isExcluded[account].fromFee,
            "Account already Excluded from Fee"
        );
        _isExcluded[account].fromFee = true;
    }

    function includeInFee(address account) external onlyOwner {
        require(
            _isExcluded[account].fromFee,
            "Account already Included in Fee"
        );
        _isExcluded[account].fromFee = false;
    }


    /// Set amount expected via tokens (do not add decimals)
    function setMinimumTokensToEarnDividends(
        uint128 minimumTokenBalanceForDividends
    ) external onlyOwner {
        _dividends.updateMinimumTokenBalanceForDividends(
            minimumTokenBalanceForDividends
        );
    }

    function updateClaimWait(uint24 claimWait) external onlyOwner {
        _dividends.updateClaimWait(claimWait);
    }

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = _dividends.process(gas);

        emit ProcessedDividends(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function claim() external {
        _dividends.processAccount(_msgSender(), false);
    }

    function getAccountDividendsInfo(address account)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return _dividends.getAccount(account);
    }

    function getDividendsAddress() external view returns (address) {
        return address(_dividends);
    }

    function getMinimumTokenBalanceToEarnDividends()
        external
        view
        returns (uint128)
    {
        return uint128(_dividends.minimumTokenBalanceForDividends());
    }

    function getMinimumTokensBeforeSell() external view returns (uint128) {
        return _getTracker(3, 1);
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply - _balances[_burnAddress];
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function getTracker(uint8 index, uint8 subIndex)
        external
        view
        returns (uint128)
    {
        return _getTracker(index, subIndex);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
    }

        return true;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcluded[account].fromFee;
    }

    function name() external pure returns (string memory) {
        return "Life Token v2";
    }

    function symbol() external pure returns (string memory) {
        return "LTNv2";
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }

    function _transfer(
        address from,
        address to,
        uint128 amount
    ) private {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            _balances[from] >= amount,
            "Balance must be greater than amount"
        );

        if (_isExcluded[from].fromFee || _isExcluded[to].fromFee) {
            _transferType = TransferType.Excluded;
        } else if (to == PancakePair || from == PancakePair) {
            _transferType = to == PancakePair
                ? TransferType.Sell
                : TransferType.Buy;
        } else {
            _transferType = TransferType.Default;
        }

        uint128 tokenFees;
        if (!_lockSwap && _transferType != TransferType.Excluded) {
            (
                uint16 charityRate,
                uint16 marketingRate,
                uint16 dividendsRate,
                uint16 liquidityPoolRate,
                uint16 buyBackBurnRate
            ) = getRates();

            uint128 minimumTokensForSell = _getTracker(3, 1);
            uint128 charityFee;
            uint128 marketingFee;
            uint128 dividendsFee;
            uint128 liquidityFee;
            uint128 buyBackFee;

            if (charityRate > 0)
                charityFee = (amount * charityRate) / DENOMINATOR;

            if (marketingRate > 0)
                marketingFee = (amount * marketingRate) / DENOMINATOR;

            if (dividendsRate > 0)
                dividendsFee = (amount * dividendsRate) / DENOMINATOR;

            if (liquidityPoolRate > 0) 
                liquidityFee = (amount * liquidityPoolRate) / DENOMINATOR;

            if (buyBackBurnRate > 0)
                buyBackFee += (amount * buyBackBurnRate) / DENOMINATOR;

            tokenFees +=
                charityFee +
                marketingFee +
                dividendsFee +
                liquidityFee +
                buyBackFee;

            _balances[address(this)] += tokenFees;
            
            if (
                _balances[address(this)] >= minimumTokensForSell &&
                _transferType == TransferType.Sell
            ) {
                sellTokensPlusAddLiquidity(minimumTokensForSell);
            } else {
                setTracker(0, 0, charityFee, true);
                setTracker(0, 1, marketingFee, true);
                setTracker(1, 0, dividendsFee, true);
                setTracker(1, 1, liquidityFee, true);
                setTracker(2, 0, buyBackFee, true);
            }
        }

        finishTransfer(from, to, tokenFees, amount);
    }

    function sellTokensPlusAddLiquidity(
        uint128 minimumTokensForSell
    ) private LockSwap {
        (uint128 tokensToSell, uint128 tokensForLP) = getExtraLiquidation(
            minimumTokensForSell
        );

        uint128 liquidityBnb;
        if (tokensToSell > 0) {
            liquidityBnb = sellTokensAndSendBnb(tokensToSell);
        }
        
        if (tokensForLP > 0 && liquidityBnb > 0) {
            addLiquidity(tokensForLP, liquidityBnb);
        }
    }
    
    function getExtraLiquidation(uint128 minimumTokensForSell)
        private
        returns (uint128, uint128)
    {
        (
            uint16 charityRate,
            uint16 marketingRate,
            uint16 dividendsRate,
            uint16 liquidityPoolRate,
            uint16 buyBackBurnRate
        ) = getRates();
        uint24 commonRateDenominator = charityRate +
            marketingRate +
            dividendsRate +
            liquidityPoolRate +
            buyBackBurnRate + 12000;
        uint128 charityFee;
        uint128 marketingFee;
        uint128 dividendsFee;
        uint128 liquidityFee;
        uint128 buybackFee;

        if (charityRate > 0) {
            charityFee = minimumTokensForSell * (charityRate + 1000) / commonRateDenominator;

            setTracker(0, 0, charityFee, false);
        }
        
        if (marketingRate > 0) {
            marketingFee = minimumTokensForSell * (marketingRate + 2000) / commonRateDenominator;

            setTracker(0, 1, marketingFee, false);
        }
        if (dividendsRate > 0) {
            dividendsFee = minimumTokensForSell * (dividendsRate + 5000) / commonRateDenominator;

            setTracker(1, 0, dividendsFee, false);
        }
        if (liquidityPoolRate > 0) {
            liquidityFee = minimumTokensForSell * (liquidityPoolRate + 2000) / commonRateDenominator;

            setTracker(1, 1, liquidityFee, false);
            liquidityFee /= 2;
        }

        if (buyBackBurnRate > 0) {
            buybackFee = minimumTokensForSell * (buyBackBurnRate + 2000) / commonRateDenominator;

            setTracker(2, 0, buybackFee, false);
        }

        return (
            (charityFee +
                marketingFee +
                dividendsFee +
                liquidityFee +
                buybackFee),
            liquidityFee
        );
    }


    function sellTokensAndSendBnb(uint128 tokensToSell)
        private 
        returns (uint128)
    {

        // generate the Pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = PancakeRouter.WETH();
        
        _approve(address(this), address(PancakeRouter), tokensToSell);
        
        // make the swap
        PancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSell,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
        uint128 liquidityFee;
        (
            uint16 charityRate,
            uint16 marketingRate,
            uint16 dividendsRate,
            uint16 liquidityPoolRate,
            uint16 buybackRate
        ) = getRates();
        

        uint24 commonRateDenominator = charityRate + marketingRate + dividendsRate + liquidityPoolRate + buybackRate + 12000;
        if (address(this).balance > 0) {
            
            if (liquidityPoolRate > 0) {
                liquidityFee = uint128(address(this).balance);
                liquidityFee *= (liquidityPoolRate + 2000) ;
            }
        }

        sendBNB(commonRateDenominator, address(this).balance);

        emit SwapTokensForBNB(tokensToSell, uint128(address(this).balance));
        

        return (liquidityFee / commonRateDenominator);
        
        
    }

    function sendBNB(
        uint24 commonRateDenominator,
        uint256 bnbReceived
    ) private {
        bool success;

        (
            uint16 charityRate,
            uint16 marketingRate,
            uint16 dividendsRate,
            ,

        ) = getRates();

        if (charityRate > 0) {
            uint256 charityBNB = (bnbReceived * (charityRate + 1000) / commonRateDenominator);

            (success, ) = _charityAddress.call{value: charityBNB}("");

            if (success)
                emit SendToWallet("Charity", _charityAddress, charityBNB);
        }

        if (marketingRate > 0) {
            uint256 marketingBNB = (bnbReceived * (marketingRate + 2000) / commonRateDenominator);

            (success, ) = _marketingAddress.call{value: marketingBNB}("");

            if (success)
                emit SendToWallet("Marketing", _marketingAddress, marketingBNB);
        }

        if (dividendsRate > 0) {
            uint256 dividendsBNB = (bnbReceived * (dividendsRate + 5000) / commonRateDenominator);

            (success, ) = address(_dividends).call{value: dividendsBNB}("");

            if (success)
                emit SendToWallet(
                    "Dividends",
                    address(_dividends),
                    dividendsBNB
                );
        }
    }
    
    

    function addLiquidity(uint128 tokenAmount, uint128 bnbAmount) private {
        bool success;
        _approve(address(this), address(PancakeRouter), tokenAmount);

        PancakeRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit AddLiquidity(tokenAmount, bnbAmount, PancakePair);
        
        uint256 buyBackBNB = address(this).balance;

        (success, ) = _buyBackAddress.call{value: buyBackBNB}("");

        if (success)
            emit SendToWallet("Marketing", _buyBackAddress, buyBackBNB);
    }

    function getRates()
        private
        view
        returns (
            uint16,
            uint16,
            uint16,
            uint16,
            uint16
        )
    {
        uint16 charityRate;
        uint16 marketingRate;
        uint16 dividendsRate;
        uint16 liquidityPoolRate;
        uint16 buyBackBurnRate;
        uint64 timepassed = uint64(block.timestamp);

        if (
            _transferType == TransferType.Buy ||
            _transferType == TransferType.Default
        ) {
            charityRate = 1000;
            marketingRate = 2000;
            dividendsRate = 5000;
            liquidityPoolRate = 2000;
            buyBackBurnRate = 2000;
        } else {
            charityRate = 1000;

            if (timepassed >= (_creationDate + 7 weeks)) {
                dividendsRate = 11000;
                liquidityPoolRate = 2000;
            } else if (timepassed >= (_creationDate + 6 weeks)) {
                dividendsRate = 10250;
                liquidityPoolRate = 2750;
            } else if (timepassed >= (_creationDate + 5 weeks)) {
                dividendsRate = 9500;
                liquidityPoolRate = 3250;
            } else if (timepassed >= (_creationDate + 4 weeks)) {
                dividendsRate = 8750;
                liquidityPoolRate = 4250;
            } else if (timepassed >= (_creationDate + 3 weeks)) {
                dividendsRate = 8000;
                liquidityPoolRate = 7000;
            } else if (timepassed >= (_creationDate + 2 weeks)) {
                dividendsRate = 7250;
                liquidityPoolRate = 9750;
            } else if (timepassed >= (_creationDate + 1 weeks)) {
                // Day 7+
                dividendsRate = 6500;
                liquidityPoolRate = 14500;
            } else {
                // Day 0+
                dividendsRate = 5750;
                liquidityPoolRate = 19250;
            }

            if (timepassed >= (_creationDate + 4 weeks)) {
                // Day 28+
                marketingRate = 2000;
                buyBackBurnRate = 2000;
            } else if (timepassed >= (_creationDate + 3 weeks)) {
                // Day 21+
                marketingRate = 2000;
                buyBackBurnRate = 3000;
            } else if (timepassed >= (_creationDate + 2 weeks)) {
                // Day 14+
                marketingRate = 3000;
                buyBackBurnRate = 3000;
            } else {
                // Day 0-14
                marketingRate = 4000;
                buyBackBurnRate = 3000;
            }
        }

        return (
            charityRate,
            marketingRate,
            dividendsRate,
            liquidityPoolRate,
            buyBackBurnRate
        );
    }

    function finishTransfer(
        address from,
        address to,
        uint128 tokenFees,
        uint256 amount
    ) private {
        uint256 amountMinusFees = amount - tokenFees;

        _balances[from] -= uint128(amount);
        _balances[to] += (uint128(amount) - tokenFees);

        if (tokenFees > 0) emit Transfer(from, address(this), tokenFees);
        emit Transfer(from, to, amountMinusFees);

        try _dividends.setBalance(payable(from), _balances[from]) {} catch {}
        try _dividends.setBalance(payable(to), _balances[to]) {} catch {}

        if (!_lockSwap) {
            uint256 gas = _getTracker(3, 0);

            try _dividends.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividends(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {
                emit ProcessingDividendsError(msg.sender);
            }
        }
    }

    function _burn(address from, uint128 amount) private {
        _balances[from] -= amount;
        _balances[_burnAddress] += amount;

        emit Transfer(from, _burnAddress, amount);
    }

    /// Sets internal trackers used to keep track of which tokens are being used where.
    function setTracker(
        uint8 index,
        uint8 subIndex,
        uint128 value,
        bool add
    ) private {
        require(index <= 3, "index must be lower");
        require(subIndex <= 1, "subIndex must be lower");

        bytes32 tracker;
        if (index == 0) {
            tracker = _contractTrackerZero;
        } else if (index == 1) {
            tracker = _contractTrackerOne;
        } else if (index == 2) {
            tracker = _contractTrackerTwo;
        } else if (index == 3) {
            tracker = _contractTrackerThree;
        }

        subIndex *= 128;

        uint128 oldValue = uint128(bytes16(tracker << subIndex));
        uint128 newValue;

        if (index == 3) {
            newValue = value;
        } else {
            if (add) {
                newValue = oldValue + value;
            } else if (oldValue >= value) {
                newValue = oldValue - value;
            } else if (oldValue < value) {
                newValue = 0;
            }
        }

        tracker &= ~(bytes32(bytes16(~uint128(0))) >> subIndex);
        tracker |= bytes32(bytes16(uint128(newValue))) >> subIndex;

        if (index == 0) {
            _contractTrackerZero = tracker;
        } else if (index == 1) {
            _contractTrackerOne = tracker;
        } else if (index == 2) {
            _contractTrackerTwo = tracker;
        } else if (index == 3) {
            _contractTrackerThree = tracker;
        }

        emit TrackerUpdated(tracker, oldValue, newValue, add);
    }

    function _getTracker(uint8 index, uint8 subIndex)
        private
        view
        returns (uint128)
    {
        require(index <= 3, "index too high");
        require(subIndex <= 1, "subIndex too high");
        subIndex *= 128;

        uint128 value;

        if (index == 0) {
            value = uint128(bytes16(_contractTrackerZero << subIndex));
        } else if (index == 1) {
            value = uint128(bytes16(_contractTrackerOne << subIndex));
        } else if (index == 2) {
            value = uint128(bytes16(_contractTrackerTwo << subIndex));
        } else if (index == 3) {
            value = uint128(bytes16(_contractTrackerThree << subIndex));
        }

        return value;
    }

    function _verify(address from, address to) private pure {
        require(from != address(0), "ERC20: approve from the zero address");
        require(to != address(0), "ERC20: approve to the zero address");
    }
}
