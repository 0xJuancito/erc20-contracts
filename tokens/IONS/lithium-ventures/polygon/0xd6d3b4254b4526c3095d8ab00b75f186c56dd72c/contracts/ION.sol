// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./mock_router/interfaces/IUniswapV2Factory.sol";
import "./mock_router/interfaces/IUniswapV2Router02.sol";
import "./mock_router/interfaces/IUniswapV2Pair.sol";

import "./interfaces/ISuperCharge.sol";
import "./interfaces/IAirdrops.sol";
import "./interfaces/IAdmin.sol";
import "./interfaces/IERC20D.sol";

contract ION is ERC20, Ownable {

    //--------------------Other Contracts--------------------//

    IUniswapV2Router02 public uniswapV2Router;
    IAdmin public admin;
    address public USDC;

    address public devWallet;
    address public rewardsContract;

    //--------------------------Rewards-----------------------//

    uint256 public trickleChgReward;
    uint256 public superChgReward;
    uint256 public burnRebaseReward;
    uint256 public devReward;
    uint256 public liquidityReward;

    //--------------------------Time-based--------------------//

    uint256 public mintingTime = block.timestamp;
    uint256 public trickleBaseTime = block.timestamp;
    uint256 public maticDistribution = block.timestamp;
    uint256 public trickleTime = 8 hours;
    uint256 public maticRewardTime = 7 days;
    uint256 public coolDownPeriod = 30 hours;
    uint256 public buySellTime = block.timestamp + coolDownPeriod;

    //------------------------TaxPercentages------------------//

    uint256 public buyTax = 10001;
    uint256 public sellMaxTax = 10002;
    uint256 public sellMinTax = 10001;
    uint256 public txTax = 300;
    uint256 public marketCapPer = 300;
    uint256[5] public rewardsAmt;

    //----------------------Thresholds-------------------------//

    uint256 public epochEndAmt;
    uint256 public epochCurrentAmt;
    uint256 public maxLimit = 100000 * 10**18;

    //----------------------Booleans---------------------------//
    bool public enableSwapAndLiquify;
    bool public isDistributionEnabled;

    //-------------------------Constants-----------------------//

    uint256 public constant PCT_BASE = 10000;

    //-------------------------Structs----------------------//

    struct Taxes {
        uint256 individualBuy;
        uint256 individualSell;
        uint256 individualTx;
    }

    struct UserLimit {
        uint256 startTime;
        uint256 amount;
    }

    //-------------------------Mappings----------------------//

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => Taxes) public taxes;
    mapping(address => bool) public isPair;
    mapping(address => UserLimit) public userLimits;

    receive() external payable {}

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address _router,
        address _owner,
        address _devWallet,
        address _admin,
        address _deployer,
        address USDC_
    ) ERC20(name_, symbol_) {
        admin = IAdmin(_admin);
        transferOwnership(_owner);
        _mint(_deployer, totalSupply_);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        address uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[_devWallet] = true;
        _isExcludedFromFee[_deployer] = true;
        _isExcludedFromFee[address(this)] = true;
        isPair[uniswapV2Pair] = true;
        devWallet = _devWallet;
        USDC = USDC_;
        rewardsAmt = [3000, 1500, 1500, 4000, 0];
        isDistributionEnabled = true;
    }

    //---------------------------modifiers------------------------//

    modifier validation(address _address) {
        require(_address != address(0));
        _;
    }

    //---------------------------Admin-setters------------------------//

    function whitelistPair(address _newPair)
        external
        onlyOwner
        validation(_newPair)
    {
        isPair[_newPair] = true;
    }

    function setEnableSwapAndLiquify(bool _bool) external onlyOwner {
        enableSwapAndLiquify = _bool;
    }

    function setMaxLimit(uint256 _value) external onlyOwner {
        maxLimit = _value;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setRewards(uint256[5] calldata _rewardsAmt) public onlyOwner {
        uint256 total;
        for (uint8 i = 0; i < _rewardsAmt.length; i++) {
            total += _rewardsAmt[i];
        }
        require(total == PCT_BASE);
        rewardsAmt = _rewardsAmt;
    }

    function setBuyTax(uint256 _buyTax) public onlyOwner {
        buyTax = _buyTax;
    }

    function setSellTax(uint256 _sellMaxTax, uint256 _sellMinTax)
        public
        onlyOwner
    {
        require(_sellMaxTax > _sellMinTax);
        sellMaxTax = _sellMaxTax;
        sellMinTax = _sellMinTax;
    }

    function setTxTax(uint256 _txTax) public onlyOwner {
        txTax = _txTax;
    }

    function setTrickleChgTime(uint256 _time) external onlyOwner {
        trickleTime = _time;
    }

    function setMaticRewardTime(uint256 _time) external onlyOwner {
        maticRewardTime = _time;
    }

    function setRewardsContract(address _address)
        public
        onlyOwner
        validation(_address)
    {
        rewardsContract = _address;
    }

    function setDevWallet(address _address)
        public
        validation(_address)
        onlyOwner
    {
        devWallet = _address;
    }

    function setAdminContract(IAdmin _newAdmin)
        external
        onlyOwner
        validation(address(_newAdmin))
    {
        admin = _newAdmin;
    }

    function setRouter(IUniswapV2Router02 _newRouter)
        external
        onlyOwner
        validation(address(_newRouter))
    {
        uniswapV2Router = _newRouter;
    }

    function setStableCoin(address _stableCoin)
        external
        onlyOwner
        validation(_stableCoin)
    {
        USDC = _stableCoin;
    }

    function setMarketCapPercent(uint256 _percent) public onlyOwner {
        marketCapPer = _percent;
    }

    function setDistributionStatus(bool _status) public onlyOwner {
        isDistributionEnabled = _status;
    }

    function setCoolDownPeriod(uint256 _newValue) external onlyOwner {
        coolDownPeriod = _newValue;
    }

    function mint(address to, uint256 percent) public onlyOwner {
        require(block.timestamp > mintingTime + 365 days);
        require(percent <= (PCT_BASE / 10));
        uint256 mintAmount = (percent * totalSupply()) / PCT_BASE;
        _mint(to, mintAmount);
        mintingTime = block.timestamp;
    }

    function removeOtherERC20Tokens(address _tokenAddress) external onlyOwner {
        uint256 balance = IERC20D(_tokenAddress).balanceOf(address(this));
        IERC20D(_tokenAddress).transfer(devWallet, balance);
        uint256 bal = address(this).balance;

        if (bal > 0) {
            payable(devWallet).transfer(bal);
        }
    }

    //---------------------------getters------------------------//

    function getTokenPrice() public view returns (uint256) {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = USDC;
        uint256 tokenPrice = uniswapV2Router.getAmountsOut(10**18, path)[2];
        return tokenPrice;
    }

    function marketCap() public view returns (uint256) {
        return (totalSupply() * getTokenPrice()) / 10**18;
    }

    function checkEpoch() public view returns (bool) {
        return epochCurrentAmt > epochEndAmt ? true : false;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    //---------------------Internal-functions-------------------//

    function _setEpoch() internal {
        _setEpochEndAmt();
        buySellTime = block.timestamp + coolDownPeriod;
        epochCurrentAmt = 0;
    }

    function _setEpochEndAmt() internal {
        epochEndAmt = (marketCap() * marketCapPer) / (PCT_BASE);
    }

    function _tax(uint256 taxAmount_) internal {
        trickleChgReward += (taxAmount_ * rewardsAmt[0]) / PCT_BASE;
        superChgReward += (taxAmount_ * rewardsAmt[1]) / PCT_BASE;
        burnRebaseReward += (taxAmount_ * rewardsAmt[2]) / PCT_BASE;
        devReward += (taxAmount_ * rewardsAmt[3]) / PCT_BASE;

        if (rewardsAmt[4] > 0) {
            liquidityReward += (taxAmount_ * rewardsAmt[4]) / PCT_BASE;
        }
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal virtual override {
        if (_isExcludedFromFee[_sender] || _isExcludedFromFee[_recipient]) {
            super._transfer(_sender, _recipient, _amount);
            return;
        }

        uint256 taxAmount;
        uint256 remAmount;

        if (isPair[_sender]) {
            // buy
            //Condition for no buy tax deduction
            if (block.timestamp >= buySellTime && epochCurrentAmt == 0) {
                ISuperCharge(admin.superCharge()).startEpoch();
            }

            if (epochEndAmt == 0) {
                _setEpochEndAmt();
            }

            if (block.timestamp <= buySellTime) {
                super._transfer(_sender, _recipient, _amount);
                return;
            } else {
                taxAmount = _calculateBuyTax(_recipient, _amount);
            }
        } else if (isPair[_recipient]) {
            // sell
            if (block.timestamp >= buySellTime && epochCurrentAmt == 0) {
                ISuperCharge(admin.superCharge()).startEpoch();
            }
            if (epochEndAmt == 0) {
                _setEpochEndAmt();
            }

            taxAmount = _calculateSellTax(_sender, _amount);
            _checkSellLimit(_sender, _amount);
        } else {
            // if sender & receiver is not equal to pair address
            taxAmount = _calculateTxTax(_sender, _amount);

            if (isDistributionEnabled) {
                _distributeAndLiquify();
            }
        }

        if (isPair[_sender] || isPair[_recipient]) {
            if (block.timestamp > buySellTime) {
                epochCurrentAmt += ((_amount * getTokenPrice()) / (10**18));
            }

            _tax(taxAmount);
        } else {
            devReward += taxAmount;
        }

        remAmount = _amount - taxAmount;

        super._transfer(_sender, address(this), taxAmount);
        super._transfer(_sender, _recipient, remAmount);

        if (isDistributionEnabled) {
            _distribution();
        }
    }

    function _calculateBuyTax(address _user, uint256 _amount)
        internal
        view
        returns (uint256 _taxAmount)
    {
        if (taxes[_user].individualBuy > 0) {
            _taxAmount = (_amount * taxes[_user].individualBuy) / PCT_BASE;
        } else {
            _taxAmount = (_amount * buyTax) / PCT_BASE;
        }
    }

    function _calculateSellTax(address _user, uint256 _amount)
        internal
        view
        returns (uint256 _taxAmount)
    {
        uint256 diffPer = (sellMaxTax - sellMinTax);
        uint256 currentAmtPct = ((epochCurrentAmt * PCT_BASE) / epochEndAmt);
        uint256 currUserTax;
        if (block.timestamp <= buySellTime) {
            currUserTax = sellMaxTax;
        } else {
            currUserTax = (sellMaxTax - ((currentAmtPct * diffPer)) / PCT_BASE);
        }
        if (taxes[_user].individualSell > 0) {
            _taxAmount = (_amount * taxes[_user].individualSell);
        } else {
            _taxAmount = (_amount * currUserTax) / PCT_BASE;
        }
    }

    function _calculateTxTax(address _user, uint256 _amount)
        internal
        view
        returns (uint256 _taxAmount)
    {
        if (taxes[_user].individualTx > 0) {
            _taxAmount = (_amount * taxes[_user].individualTx) / PCT_BASE;
        } else {
            _taxAmount = (_amount * txTax) / PCT_BASE;
        }
    }

    function _checkSellLimit(address user, uint256 transactAmount) internal {
        if (userLimits[user].startTime + 24 hours < block.timestamp) {
            require(transactAmount <= maxLimit, "max");
            userLimits[user] = UserLimit(block.timestamp, transactAmount);
        } else {
            require(
                (maxLimit - userLimits[user].amount) >= transactAmount,
                "max"
            );
            userLimits[user].amount += transactAmount;
        }
    }

    function _distribution() internal {
        if (checkEpoch()) {
            _processSuperchargeAndBurn();
            _setEpoch();
        }

        if (block.timestamp >= trickleBaseTime + trickleTime) {
            _processTrickleAndDevRewards();
        }
    }

    function _distributeAndLiquify() internal {
        if (block.timestamp >= maticDistribution + maticRewardTime) {
            maticDistribution = block.timestamp;
            IAirdrops(admin.airdrop()).distributionMatic();
        }

        //swap and liquify
        if (enableSwapAndLiquify && (liquidityReward > 0)) {
            _swapAndLiquify();
        }
    }

    function _processSuperchargeAndBurn() internal {
        if (superChgReward > 0) {
            super._transfer(address(this), admin.superCharge(), superChgReward);
            ISuperCharge(admin.superCharge()).endEpoch(superChgReward);
            superChgReward = 0;
        }

        if (burnRebaseReward > 0) {
            _burn(address(this), burnRebaseReward);
            burnRebaseReward = 0;
        }
    }

    function _swapAndLiquify() internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        uint256 MAX_INT = 2**250;

        _approve(address(this), address(uniswapV2Router), MAX_INT);
        uint256 swapAmount = liquidityReward / 2;
        uint256 prevBal = address(this).balance;
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0,
            path,
            address(this),
            block.timestamp + 3600
        );
        if (address(this).balance > prevBal) {
            uint256 maticAmount = address(this).balance - prevBal;
            uniswapV2Router.addLiquidityETH{value: maticAmount}(
                address(this),
                swapAmount,
                0,
                0,
                address(this),
                block.timestamp + 3600
            );
            liquidityReward = 0;
        }
    }

    function _processTrickleAndDevRewards() internal {
        if (trickleChgReward > 0) {
            super._transfer(address(this), rewardsContract, trickleChgReward);
            IAirdrops(admin.airdrop()).distributionION(trickleChgReward);
            trickleChgReward = 0;
        }

        if (devReward > 0) {
            super._transfer(address(this), devWallet, devReward);
            devReward = 0;
        }

        trickleBaseTime = block.timestamp;
    }
}
