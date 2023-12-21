// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract GemdropTokenInitializable is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public constant deadAddress = address(0xdead);
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public tradingActive;
    bool public swapEnabled;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) public isBlacklisted;

    // FEES
    uint256 public constant FEE_BASE = 1000;
    uint256 public buyTotalFees; // buy fee (4%)
    uint256 public sellTotalFees; // sell fee (4%)
    uint256 public revShareFee; // 15%
    uint256 public burnFee; // 15%
    uint256 public teamFee; // 70%

    address public revShareWallet;
    address public burnWallet;
    address public teamWallet;

    // earned fees waiting for swap
    uint256 public tokensForRevShare;
    uint256 public tokensForBurn;
    uint256 public tokensForTeam;

    // swap minimum amount
    uint256 public swapTokensAtAmount;

    bool private swapping;

    /******************/

    // exclude from fees and max transaction amount
    mapping(address => bool) public isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event RevShareWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );
    event TeamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );
    event BurnWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error ZeroAddress();
    error SenderBlacklisted();
    error ReceiverBlacklisted();
    error TradingNotActive();
    error NativeSendFailed();
    error CannotBlacklistLpOrPool();
    error FeeCannotBeHigher(uint256 max, uint256 provided);

    receive() external payable {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_,
        IUniswapV2Router02 uniswapV2Router_,
        uint256 initialSupply_,
        address revShareWallet_,
        address burnWallet_,
        address teamWallet_
    ) external initializer {
        // base contracts
        __ERC20_init(name_, symbol_);
        _transferOwnership(owner_);

        // static variables
        buyTotalFees = 40; // buy fee (4%)
        sellTotalFees = 40; // sell fee (4%)
        revShareFee = 150; // 15%
        burnFee = 150; // 15%
        teamFee = 700; // 70%

        uniswapV2Router = uniswapV2Router_;

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 totalSupply = initialSupply_;
        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05%

        revShareWallet = revShareWallet_;
        burnWallet = burnWallet_;
        teamWallet = teamWallet_;

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(deadAddress), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(msg.sender, totalSupply);
    }

    // once enabled, can never be turned off
    function startNow() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
        swapTokensAtAmount = newAmount;
    }

    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateFees(
        uint256 buyTotalFees_,
        uint256 sellTotalFees_
    ) external onlyOwner {
        if (buyTotalFees_ > 100) {
            revert FeeCannotBeHigher(100, buyTotalFees_);
        }
        if (sellTotalFees_ > 100) {
            revert FeeCannotBeHigher(100, sellTotalFees_);
        }
        buyTotalFees = buyTotalFees_;
        sellTotalFees = sellTotalFees_;
    }

    function updateFeeDistribution(
        uint256 revShareFee_,
        uint256 liquidityFee_
    ) external onlyOwner {
        if (revShareFee_ + liquidityFee_ > FEE_BASE) {
            revert FeeCannotBeHigher(FEE_BASE, revShareFee_ + liquidityFee_);
        }
        revShareFee = revShareFee_;
        burnFee = liquidityFee_;
        teamFee = FEE_BASE - revShareFee_ - liquidityFee_;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        if (pair == uniswapV2Pair) {
            revert CannotBlacklistLpOrPool();
        }

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateRevShareWallet(
        address newRevShareWallet
    ) external onlyOwner {
        emit RevShareWalletUpdated(newRevShareWallet, revShareWallet);
        revShareWallet = newRevShareWallet;
    }

    function updateTeamWallet(address newWallet) external onlyOwner {
        emit TeamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
    }

    function updateBurnWallet(address newWallet) external onlyOwner {
        emit BurnWalletUpdated(newWallet, burnWallet);
        burnWallet = newWallet;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0)) {
            revert TransferFromZeroAddress();
        }
        if (to == address(0)) {
            revert TransferToZeroAddress();
        }
        if (isBlacklisted[from]) {
            revert SenderBlacklisted();
        }
        if (isBlacklisted[to]) {
            revert ReceiverBlacklisted();
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (
            from != owner() &&
            to != owner() &&
            to != address(0) &&
            to != address(deadAddress) &&
            !swapping
        ) {
            if (!tradingActive) {
                if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
                    revert TradingNotActive();
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !isExcludedFromFees[from] &&
            !isExcludedFromFees[to]
        ) {
            swapping = true;
            _swapBack();
            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / FEE_BASE;
                tokensForBurn += (fees * burnFee) / FEE_BASE;
                tokensForTeam += (fees * teamFee) / FEE_BASE;
                tokensForRevShare += (fees * revShareFee) / FEE_BASE;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / FEE_BASE;
                tokensForBurn += (fees * burnFee) / FEE_BASE;
                tokensForTeam += (fees * teamFee) / FEE_BASE;
                tokensForRevShare += (fees * revShareFee) / FEE_BASE;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
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

    function addLiquidity() external onlyOwner {
        _addLiquidity(balanceOf(address(this)), address(this).balance);
    }

    function _swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForBurn +
            tokensForRevShare +
            tokensForTeam;
        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount * 20) {
            contractBalance = swapTokensAtAmount * 20;
        }

        uint256 initialETHBalance = address(this).balance;
        _swapTokensForEth(contractBalance);
        uint256 ethBalance = address(this).balance - initialETHBalance;

        uint256 ethForRevShare = (ethBalance * tokensForRevShare) /
            totalTokensToSwap;
        uint256 ethForBurn = (ethBalance * tokensForBurn) / totalTokensToSwap;

        tokensForRevShare = 0;
        tokensForTeam = 0;
        tokensForBurn = 0;

        bool success;
        (success, ) = address(revShareWallet).call{value: ethForRevShare}("");
        if (!success) {
            revert NativeSendFailed();
        }

        (success, ) = address(burnWallet).call{value: ethForBurn}("");
        if (!success) {
            revert NativeSendFailed();
        }

        (success, ) = address(teamWallet).call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert NativeSendFailed();
        }
    }

    function withdrawStuckSelf() external onlyOwner {
        uint256 balance = IERC20Upgradeable(address(this)).balanceOf(address(this));
        IERC20Upgradeable(address(this)).transfer(_msgSender(), balance);
        payable(_msgSender()).transfer(address(this).balance);
    }

    function withdrawStuckToken(
        address _token,
        address _to
    ) external onlyOwner {
        if (_token == address(0)) {
            revert ZeroAddress();
        }
        uint256 _contractBalance = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).transfer(_to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{value: address(this).balance}("");
        require(success);
    }

    function blacklist(address _addr) public onlyOwner {
        if (
            _addr == address(uniswapV2Pair) || _addr == address(uniswapV2Router)
        ) {
            revert CannotBlacklistLpOrPool();
        }
        isBlacklisted[_addr] = true;
    }

    // @dev blacklist v3 pools; can unblacklist() down the road to suit project and community
    function blacklistLiquidityPool(address lpAddress) public onlyOwner {
        if (
            lpAddress == address(uniswapV2Pair) ||
            lpAddress == address(uniswapV2Router)
        ) {
            revert CannotBlacklistLpOrPool();
        }
        isBlacklisted[lpAddress] = true;
    }

    // @dev unblacklist address; not affected by blacklistRenounced incase team wants to unblacklist v3 pools down the road
    function unblacklist(address _addr) public onlyOwner {
        delete isBlacklisted[_addr];
    }

    function setRouterAndPairAddress(
        IUniswapV2Router02 uniswapV2Router_,
        address uniswapV2Pair_
    ) external onlyOwner {
        uniswapV2Router = uniswapV2Router_;
        uniswapV2Pair = uniswapV2Pair_;
    }

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
