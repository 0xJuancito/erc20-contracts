// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "./pancake/IPancakeV2Router02.sol";
import "./pancake/IPancakeV2Factory.sol";
import "./pancake/IPancakeV2Pair.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Cakebot is ERC20, Ownable {
    IPancakeV2Router02 public constant pancakeV2Router =
        IPancakeV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public immutable pancakeV2Pair;
    bool private swapping;
    address public revShareWallet;
    address public teamWallet;
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
    uint256 public buyTeamFee;
    uint256 public sellTotalFees;
    uint256 public sellRevShareFee;
    uint256 public sellLiquidityFee;
    uint256 public sellTeamFee;
    uint256 public tokensForRevShare;
    uint256 public tokensForLiquidity;
    uint256 public tokensForTeam;
    mapping(address => bool) blacklisted;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;
    mapping(address => bool) public automatedMarketMakerPairs;

    constructor(address revshare, address team)
        ERC20("Cakebot Token", "CAKEBOT")
    {
        excludeFromMaxTransaction(address(pancakeV2Router), true);
        pancakeV2Pair = IPancakeV2Factory(pancakeV2Router.factory()).createPair(
            address(this),
            pancakeV2Router.WETH()
        );
        excludeFromMaxTransaction(address(pancakeV2Pair), true);
        _setAutomatedMarketMakerPair(address(pancakeV2Pair), true);
        uint256 totalSupply = 1_000_000 * 1e18;
        maxTransactionAmount = 10_000 * 1e18;
        maxWallet = 10_000 * 1e18;
        swapTokensAtAmount = (totalSupply * 5) / 10000;
        buyRevShareFee = 2;
        buyLiquidityFee = 1;
        buyTeamFee = 2;
        buyTotalFees = buyRevShareFee + buyLiquidityFee + buyTeamFee;
        sellRevShareFee = 2;
        sellLiquidityFee = 1;
        sellTeamFee = 2;
        sellTotalFees = sellRevShareFee + sellLiquidityFee + sellTeamFee;
        revShareWallet = revshare;
        teamWallet = team;
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    function isExcludedFromFees(address _account) public view returns (bool) {
        return _isExcludedFromFees[_account];
    }

    function isBlacklisted(address _account) public view returns (bool) {
        return blacklisted[_account];
    }

    function removeLimits() external onlyOwner {
        limitsInEffect = false;
    }

    function updateSwapTokensAtAmount(uint256 _amount) external onlyOwner {
        if (_amount < (totalSupply() * 1) / 100000) {
            revert SwapAmountTooLow(_amount);
        } else if (_amount > (totalSupply() * 5) / 1000) {
            revert SwapAmountTooHigh(_amount);
        }
        swapTokensAtAmount = _amount;
    }

    function setMaxTransactionAmount(uint256 _amount) external onlyOwner {
        if (_amount < ((totalSupply() * 5) / 1000) / 1e18) {
            revert MaxTransactionAmountTooLow(_amount);
        }
        maxTransactionAmount = _amount * (10**18);
    }

    function updateMaxWalletAmount(uint256 _amount) external onlyOwner {
        if (_amount < ((totalSupply() * 5) / 1000) / 1e18) {
            revert MaxWalletAmountTooLow(_amount);
        }
        maxWallet = _amount * (10**18);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function updateSwapEnable(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateBuyFees(
        uint256 _revShareFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        buyRevShareFee = _revShareFee;
        buyLiquidityFee = _liquidityFee;
        buyTeamFee = _teamFee;
        buyTotalFees = buyRevShareFee + buyLiquidityFee + buyTeamFee;
        if (buyTotalFees > 5) {
            revert BuyFeesTooHigh(buyTotalFees);
        }
    }

    function updateSellFees(
        uint256 _revShareFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        sellRevShareFee = _revShareFee;
        sellLiquidityFee = _liquidityFee;
        sellTeamFee = _teamFee;
        sellTotalFees = sellRevShareFee + sellLiquidityFee + sellTeamFee;
        if (sellTotalFees > 5) {
            revert SellFeesTooHigh(sellTotalFees);
        }
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        if (pair == pancakeV2Pair) {
            revert ImmutablePair(pair);
        }
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateRevShareWallet(address newRevShareWallet)
        external
        onlyOwner
    {
        emit revShareWalletUpdated(newRevShareWallet, revShareWallet);
        revShareWallet = newRevShareWallet;
    }

    function updateTeamWallet(address newWallet) external onlyOwner {
        emit teamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
    }

    modifier checkLimits(
        address _from,
        address _to,
        uint256 _amount
    ) {
        if (limitsInEffect) {
            if (
                _from != owner() &&
                _to != owner() &&
                _to != address(0) &&
                !swapping
            ) {
                if (
                    automatedMarketMakerPairs[_from] &&
                    !_isExcludedMaxTransactionAmount[_to]
                ) {
                    require(
                        _amount <= maxTransactionAmount,
                        "Buy transfer amount exceeds the maxTransactionAmount."
                    );
                    require(
                        _amount + balanceOf(_to) <= maxWallet,
                        "Max wallet exceeded"
                    );
                } else if (
                    automatedMarketMakerPairs[_to] &&
                    !_isExcludedMaxTransactionAmount[_from]
                ) {
                    require(
                        _amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
                } else if (!_isExcludedMaxTransactionAmount[_to]) {
                    require(
                        _amount + balanceOf(_to) <= maxWallet,
                        "Max wallet exceeded"
                    );
                }
            }
        }
        _;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override checkLimits(from, to, amount) {
        require(
            swapEnabled || from == owner() || to == owner(),
            "Swapping not enabled yet"
        );
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!blacklisted[from], "Sender blacklisted");
        require(!blacklisted[to], "Receiver blacklisted");
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;
            swapBack();
            swapping = false;
        }
        bool takeFee = !swapping;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        uint256 fees = 0;
        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / 100;
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForTeam += (fees * sellTeamFee) / sellTotalFees;
                tokensForRevShare += (fees * sellRevShareFee) / sellTotalFees;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / 100;
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForTeam += (fees * buyTeamFee) / buyTotalFees;
                tokensForRevShare += (fees * buyRevShareFee) / buyTotalFees;
            }
            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
            amount -= fees;
        }
        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeV2Router.WETH();
        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity +
            tokensForRevShare +
            tokensForTeam;
        bool success;
        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }
        if (contractBalance > swapTokensAtAmount * 20) {
            contractBalance = swapTokensAtAmount * 20;
        }
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
            totalTokensToSwap /
            2;
        uint256 amountToSwapForETH = contractBalance - liquidityTokens;
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(amountToSwapForETH);
        uint256 ethBalance = address(this).balance - initialETHBalance;
        uint256 ethForRevShare = (ethBalance * tokensForRevShare) /
            (totalTokensToSwap - (tokensForLiquidity / 2));
        uint256 ethForTeam = (ethBalance * tokensForTeam) /
            (totalTokensToSwap - (tokensForLiquidity / 2));
        uint256 ethForLiquidity = ethBalance - ethForRevShare - ethForTeam;
        tokensForLiquidity = 0;
        tokensForRevShare = 0;
        tokensForTeam = 0;
        (success, ) = address(teamWallet).call{value: ethForTeam}("");
        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }
        (success, ) = address(revShareWallet).call{
            value: address(this).balance
        }("");
    }

    function withdrawStuckCakebot() external onlyOwner {
        uint256 balance = IERC20(address(this)).balanceOf(address(this));
        IERC20(address(this)).transfer(msg.sender, balance);
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawStuckToken(address _token, address _to)
        external
        onlyOwner
    {
        if (_token == address(0)) {
            revert TokenAddressZero();
        }
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{value: address(this).balance}("");
        require(success);
    }

    function renounceBlacklist() public onlyOwner {
        blacklistRenounced = true;
    }

    function blacklist(address _addr) public onlyOwner {
        require(!blacklistRenounced, "Team has revoked blacklist rights");
        if (
            _addr == address(pancakeV2Pair) || _addr == address(pancakeV2Router)
        ) {
            revert BlacklistImmune(_addr);
        }
        blacklisted[_addr] = true;
    }

    function unblacklist(address _addr) public onlyOwner {
        blacklisted[_addr] = false;
    }

    event UpdatePancakeV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event revShareWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );
    event teamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    error SwapAmountTooLow(uint256 amount);
    error SwapAmountTooHigh(uint256 amount);
    error MaxTransactionAmountTooLow(uint256 amount);
    error MaxWalletAmountTooLow(uint256 amount);
    error BuyFeesTooHigh(uint256 amount);
    error SellFeesTooHigh(uint256 amount);
    error ImmutablePair(address pair);
    error TokenAddressZero();
    error BlacklistImmune(address addr);
}
