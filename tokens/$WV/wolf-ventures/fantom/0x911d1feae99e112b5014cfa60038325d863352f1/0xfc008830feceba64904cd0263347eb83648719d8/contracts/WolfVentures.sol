// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./extensions/ERC20FeesableUpgradeable.sol";
import "./extensions/ERC20ProtectableUpgradeable.sol";
import "./interfaces/IDexRouter.sol";
import "./interfaces/IDexFactory.sol";

contract WolfVentures is Initializable, ERC20Upgradeable, ERC20ProtectableUpgradeable, ERC20FeesableUpgradeable, OwnableUpgradeable {
    IDexRouter public dexRouter;
    address public lpPair;
    address payable public treasuryAddress;
    bool private transferringFees;
    uint256 public tokensForTreasury;
    uint256 public tokensForBurn;

    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => uint256) private _holderLastTransferTimestamp;

    event UpdatedTreasuryAddress(address indexed newWallet);
    event TransferForeignToken(address token, uint256 amount);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        address payable newOwner = payable(msg.sender);
        address _dexRouter = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        treasuryAddress = payable(0xC24BaDF40e4687ea6a318FA86e4dEa8d7C307626);
        dexRouter = IDexRouter(_dexRouter);
        uint256 totalSupply = 100_000_000 * 10 ** decimals();
        _mint(newOwner, totalSupply);
        __ERC20_init("Wolf Ventures", "WV");
        __Ownable_init();
        __ERC20Feesable_init(3, 0, 10);
        __ERC20Protectable_init();

        _excludeFromFees(newOwner, true);
        _excludeFromFees(address(this), true);
        _excludeFromFees(address(treasuryAddress), true);
        _excludeFromFees(address(dexRouter), true);

        _excludeFromMaxTransaction(address(lpPair), true);
        _excludeFromMaxTransaction(newOwner, true);
        _excludeFromMaxTransaction(address(this), true);
        _excludeFromMaxTransaction(address(treasuryAddress), true);
        _excludeFromMaxTransaction(address(dexRouter), true);

        changeRouterVersion(_dexRouter);
        transferOwnership(newOwner);
    }

    receive() external payable {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function changeRouterVersion(address _router) public onlyOwner returns (address _pair) {
        IDexRouter router = IDexRouter(_router);

        _pair = IDexFactory(router.factory()).getPair(address(this), router.WETH());
        if (_pair == address(0)) {
            // Pair doesn't exist
            _pair = IDexFactory(router.factory()).createPair(address(this), router.WETH());
        }
        lpPair = _pair;

        // Set the router of the contract variables
        dexRouter = router;

        _setAutomatedMarketMakerPair(address(lpPair), true);
    }

    function setTreasuryAddress(  address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "_treasuryAddress address cannot be 0");
        treasuryAddress = payable(_treasuryAddress);
        emit UpdatedTreasuryAddress(_treasuryAddress);
    }

    function transferForeignToken(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0), "_token address cannot be 0");
        require(_token != address(this) || !tradingActive, "Can't withdraw native tokens while trading is active");
        uint256 _contractBalance = IERC20Upgradeable(_token).balanceOf(address(this));
        _sent = IERC20Upgradeable(_token).transfer(_to, _contractBalance);
        emit TransferForeignToken(_token, _contractBalance);
    }

    //expose fees
    function updateBuyFees(uint256 treasuryFee, uint256 burnFee) external onlyOwner {
        _updateBuyFees(treasuryFee, burnFee);
    }

    function updateSellFees(uint256 treasuryFee, uint256 burnFee) external onlyOwner {
        _updateSellFees(treasuryFee, burnFee);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        _excludeFromFees(account, excluded);
    }

    function resetTaxes() external onlyOwner {
        _resetTaxes();
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != lpPair, "The pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        _excludeFromMaxTransaction(pair, value);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    //protection
    function excludeFromMaxTransaction(address wallet, bool isExclude) external onlyOwner {
        if (!isExclude) require(wallet != lpPair, "Cannot remove origin pair from max txn");
        _excludeFromMaxTransaction(wallet, isExclude);
    }

    function removeBoughtEarly(address wallet) external onlyOwner {
        _removeBoughtEarly(wallet);
    }

    function getEarlyBuyers() external view returns (address[] memory) {
        return _getEarlyBuyers();
    }

    function markBoughtEarly(address wallet) external onlyOwner {
        _markBoughtEarly(wallet);
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
        _updateSwapTokensAtAmount(newAmount);
    }

    function removeLimits() external onlyOwner {
        _removeLimits();
    }

    function restoreLimits() external onlyOwner {
        _restoreLimits();
    }

    // Enable selling - cannot be turned off!
    function setSellingEnabled(bool confirmSellingEnabled) external onlyOwner {
        _setSellingEnabled(confirmSellingEnabled);
    }

    function startTrading(uint256 blocksForPenalty) external onlyOwner {
        _startTrading(blocksForPenalty);
    }

    //xfer

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "amount must be greater than 0");

        if (!tradingActive) {
            require(getIsExcludedFromFee(from) || getIsExcludedFromFee(to), "Trading is not active.");
        }

        if (!earlyBuyPenaltyInEffect() && tradingActive) {
            require(
                !boughtEarly[from] || to == owner() || to == address(0xdead),
                "Bots cannot transfer tokens in or out except to owner or dead address."
            );
        }

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0xdead) &&
                !getIsExcludedFromFee(from) &&
                !getIsExcludedFromFee(to)
            ) {
                //when buy
                if (automatedMarketMakerPairs[from] && !getIsExcludedFromMaxAmount(to)) {
                    require(amount <= maxBuyAmount, "Buy transfer amount exceeds the max buy.");
                    require(amount + balanceOf(to) <= maxWallet, "Max Wallet Exceeded");
                }
                //when sell
                else if (automatedMarketMakerPairs[to] && !getIsExcludedFromMaxAmount(from)) {
                    require(sellingEnabled, "Selling disabled");
                    require(amount <= maxSellAmount, "Sell transfer amount exceeds the max sell.");
                } else if (!getIsExcludedFromMaxAmount(to)) {
                    require(amount + balanceOf(to) <= maxWallet, "Max Wallet Exceeded");
                }
            }
        }


        bool isExcludedFromFee = getIsExcludedFromFee(from) || getIsExcludedFromFee(to);

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (!isExcludedFromFee) {
            // bot/sniper penalty.
            if ((earlyBuyPenaltyInEffect() || (amount >= maxBuyAmount - .9 ether && blockForPenaltyEnd + 8 >= block.number)) &&
            automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to] && !getIsExcludedFromFee(to) && getBuyFee() > 0) {
                if (!earlyBuyPenaltyInEffect()) {
                    // reduce by 1 wei per max buy over what Uniswap will allow to revert bots as best as possible to limit erroneously blacklisted wallets. First bot will get in and be blacklisted, rest will be reverted (*cross fingers*)
                    maxBuyAmount -= 1;
                }

                if (!boughtEarly[to]) {
                    triggerBotCought(to);
                }

                (uint256 fee, uint256 tokenForTreasury, uint256 tokenForBurn) = _calculateBotFees(amount);
                fees = fee;
                tokensForTreasury += tokenForTreasury;
                tokensForBurn += tokenForBurn;
            }
            // on sell
            else if (automatedMarketMakerPairs[to] && getSellFee() > 0) {
                (uint256 fee, uint256 tokenForTreasury, uint256 tokenForBurn) = _calculateSellFees(amount);
                fees = fee;
                tokensForTreasury += tokenForTreasury;
                tokensForBurn += tokenForBurn;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && getBuyFee() > 0) {
                (uint256 fee, uint256 tokenForTreasury, uint256 tokenForBurn) = _calculateBuyFees(amount);
                fees = fee;
                tokensForTreasury += tokenForTreasury;
                tokensForBurn += tokenForBurn;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);


        if (getCanTransferFees() && transferFeesEnabled && !transferringFees) {
            transferringFees = true;
            transferFees();
            transferringFees = false;
        }
    }

    function getCanTransferFees() private view returns (bool){

        uint256 contractTokenBalance = balanceOf(address(owner()));

        return contractTokenBalance >= swapTokensAtAmount;
    }


    function transferFees() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForBurn + tokensForTreasury;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        //burn
        if (tokensForBurn > 0) {
            _burn(address(this), tokensForBurn);
            tokensForBurn = 0;
        }

        //transfer treasury
        if (tokensForTreasury > 0) {
            _approve(address(this), treasuryAddress, tokensForTreasury);
            _transfer(address(this), treasuryAddress, tokensForTreasury);
            tokensForTreasury = 0;
            //            (bool success,) = address(treasuryAddress).call{value : address(this).balance}("");
        }

    }


    function swapTokensForFtm(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        _approve(address(this), address(dexRouter), tokenAmount);

        // make the swap
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of FTM
            path,
            address(this),
            block.timestamp
        );
    }

    // withdraw ETH if stuck or someone sends to the address
    function withdrawStuckETH() external onlyOwner {
        bool success;
        (success,) = address(msg.sender).call{value : address(this).balance}("");
    }

    function burn(uint256 amount) public onlyOwner {
        super._burn(msg.sender, amount);
    }

    function getLpAddress() public view onlyOwner returns (address){
        return lpPair;
    }

}
