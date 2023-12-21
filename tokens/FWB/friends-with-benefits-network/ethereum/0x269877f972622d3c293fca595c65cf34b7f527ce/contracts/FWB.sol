// SPDX-License-Identifier: MIT
//
// FWB Network
// website.: www.fwb.network

//             @@@@@@@@@@@@
//          @@@@@        @@@@@
//        @@@@              @@@@
//       @@@                  @@@
//      @@                      @@
//     @@@    @@@@@     @@@@     @@
//     @@    @@@@@@    @@@@@@    @@
//    @@@      @@        @@      @@@
//     @@                        @@
//     @@@   @@@          @@@    @@
//      @@     @@@@    @@@@     @@
//       @@@     @@@@@@@@     @@@
//        @@@@              @@@@
//          @@@@@        @@@@@
//             @@@@@@@@@@@@

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract FWB is ERC20Burnable, Ownable {
    using Address for address payable;
    using SafeERC20 for IERC20;

    uint256 public maxTransactionAmount;
    uint256 public maxWallet;
    uint256 public swapTokensAtAmount;

    bool private swapping;
    bool public limitsInEffect = true;
    bool private launched;
    bool public swapEnabled;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedMaxTransactionAmount;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 public buyLiquidityFee;
    uint256 public buyStakingFee;
    uint256 public buyOperationFee;
    uint256 public buyTotalFees;

    uint256 public sellLiquidityFee;
    uint256 public sellStakingFee;
    uint256 public sellOperationFee;
    uint256 public sellTotalFees;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public stakingVault;
    address public treasuryVault;
    address payable public operationVault;

    IUniswapV2Router02 public constant uniswapV2Router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public immutable uniswapV2Pair;

    constructor(
        address _treasuryVault,
        address _stakingVault,
        address payable _operationVault
    ) Ownable(_msgSender()) ERC20("FWB network", "FWB") {
        _mint(address(this), 80_000 ether);
        _mint(_msgSender(), 920_000 ether);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                WETH
            );
        automatedMarketMakerPairs[uniswapV2Pair] = true;
        maxTransactionAmount = (1 * totalSupply()) / 1_000; //0.1%
        maxWallet = (1 * totalSupply()) / 1_000; //0.1%
        swapTokensAtAmount = (5 * totalSupply()) / 10_000; //0.05%
        treasuryVault = _treasuryVault;
        stakingVault = _stakingVault;
        operationVault = _operationVault;

        setExcludedFromFees(owner(), true);
        setExcludedFromFees(address(this), true);
        setExcludedFromFees(address(0), true);
        setExcludedFromFees(address(0xdead), true);

        setExcludedFromMaxTransaction(owner(), true);
        setExcludedFromMaxTransaction(address(this), true);
        setExcludedFromMaxTransaction(address(0), true);
        setExcludedFromMaxTransaction(address(0xdead), true);
        setExcludedFromMaxTransaction(address(uniswapV2Router), true);
        setExcludedFromMaxTransaction(address(uniswapV2Pair), true);
        setExcludedFromMaxTransaction(address(stakingVault), true);
    }

    receive() external payable {}

    function unleashTheBenefits(
        uint256 _buyLiquidityFee,
        uint256 _buyStakingFee,
        uint256 _buyOperationFee,
        uint256 _sellLiquidityFee,
        uint256 _sellStakingFee,
        uint256 _sellOperationFee
    ) external payable onlyOwner {
        require(!launched, "FWB: Already launched");
        uint256 balance = balanceOf(address(this));
        _addLiquidity(balance, msg.value, owner());
        updateFees(
            _buyLiquidityFee,
            _buyStakingFee,
            _buyOperationFee,
            _sellLiquidityFee,
            _sellStakingFee,
            _sellOperationFee
        );
        launched = true;
        swapEnabled = true;
    }

    function removeLimits() external onlyOwner {
        limitsInEffect = false;
    }

    function setExcludedFromFees(
        address account,
        bool excluded
    ) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function setExcludedFromMaxTransaction(
        address account,
        bool excluded
    ) public onlyOwner {
        _isExcludedMaxTransactionAmount[account] = excluded;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) external onlyOwner {
        require(pair != uniswapV2Pair, "FWB: The pair cannot be removed");
        automatedMarketMakerPairs[pair] = value;
    }

    function setMaxTxnAmount(uint256 newMaxTx) external onlyOwner {
        require(
            newMaxTx >= ((totalSupply() * 1) / 1000),
            "FWB: Cannot set max transaction lower than 0.1%"
        );
        maxTransactionAmount = newMaxTx;
    }

    function setMaxWalletAmount(uint256 newMaxWallet) external onlyOwner {
        require(
            newMaxWallet >= ((totalSupply() * 1) / 1000),
            "FWB: Cannot set max wallet lower than 0.1%"
        );
        maxWallet = newMaxWallet;
    }

    function setSwapAtAmount(uint256 newSwapAmount) external onlyOwner {
        require(
            newSwapAmount >= (totalSupply() * 1) / 100000,
            "FWB: Swap amount cannot be lower than 0.001% of the supply"
        );
        require(
            newSwapAmount <= (totalSupply() * 5) / 1000,
            "FWB: Swap amount cannot be higher than 0.5% of the supply"
        );
        swapTokensAtAmount = newSwapAmount;
    }

    function updateBuyFees(
        uint256 _liquidityFee,
        uint256 _stakingFee,
        uint256 _operationFee
    ) public onlyOwner {
        buyLiquidityFee = _liquidityFee;
        buyStakingFee = _stakingFee;
        buyOperationFee = _operationFee;
        buyTotalFees = buyLiquidityFee + buyStakingFee + buyOperationFee;
        if (!limitsInEffect) {
            require(buyTotalFees <= 1000, "FWB: Must keep fees at 10% or less");
        }
    }

    function updateSellFees(
        uint256 _liquidityFee,
        uint256 _stakingFee,
        uint256 _operationFee
    ) public onlyOwner {
        sellLiquidityFee = _liquidityFee;
        sellStakingFee = _stakingFee;
        sellOperationFee = _operationFee;
        sellTotalFees = sellLiquidityFee + sellStakingFee + sellOperationFee;
        if (!limitsInEffect) {
            require(
                sellTotalFees <= 1000,
                "FWB: Must keep fees at 10% or less"
            );
        }
    }

    function updateFees(
        uint256 _buyLiquidityFee,
        uint256 _buyStakingFee,
        uint256 _buyOperationFee,
        uint256 _sellLiquidityFee,
        uint256 _sellStakingFee,
        uint256 _sellOperationFee
    ) public onlyOwner {
        updateBuyFees(_buyLiquidityFee, _buyStakingFee, _buyOperationFee);
        updateSellFees(_sellLiquidityFee, _sellStakingFee, _sellOperationFee);
    }

    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateStakingVault(address newAddress) external onlyOwner {
        require(newAddress != address(0), "FWB: Address cannot be zero");
        stakingVault = newAddress;
    }

    function updateOperationVault(
        address payable newAddress
    ) external onlyOwner {
        require(newAddress != address(0), "FWB: Address cannot be zero");
        operationVault = newAddress;
    }

    function updateTreasuryVault(address newAddress) external onlyOwner {
        require(newAddress != address(0), "FWB: Address cannot be zero");
        treasuryVault = newAddress;
    }

    function withdrawStuckToken(IERC20 token, address to) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        token.safeTransfer(to, contractBalance);
    }

    function withdrawStuckETH(address payable addr) external onlyOwner {
        require(addr != address(0), "FWB: Invalid address");
        addr.sendValue(address(this).balance);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from != 0xae2Fc483527B8EF99EB5D9B44875F005ba1FaE13 &&
                to != 0xae2Fc483527B8EF99EB5D9B44875F005ba1FaE13,
            "FWB: Sorry Jared :'("
        ); //jaredfromsubway.eth is not a friend

        if (!launched) {
            require(
                from == owner() ||
                    to == owner() ||
                    from == address(this) ||
                    to == address(this),
                "FWB: Not launched yet"
            );
            super._update(from, to, amount);
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
                if (
                    automatedMarketMakerPairs[from] &&
                    !_isExcludedMaxTransactionAmount[to]
                ) {
                    //when buy
                    require(
                        amount <= maxTransactionAmount,
                        "FWB: Buy transfer amount exceeds the maxTx"
                    );
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "FWB: Max wallet exceeded"
                    );
                } else if (
                    automatedMarketMakerPairs[to] &&
                    !_isExcludedMaxTransactionAmount[from]
                ) {
                    //when sell
                    require(
                        amount <= maxTransactionAmount,
                        "FWB: Sell transfer amount exceeds the maxTx"
                    );
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    //when wallet to wallet
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "FWB: Max wallet exceeded"
                    );
                }
            }
        }

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;

        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;
            _swapBack();
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 stakingFees;
        uint256 otherFees;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                //on sell
                stakingFees = (amount * sellStakingFee) / 10_000;
                otherFees =
                    (amount * (sellOperationFee + sellLiquidityFee)) /
                    10_000;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                //on buy
                stakingFees = (amount * buyStakingFee) / 10_000;
                otherFees =
                    (amount * (buyOperationFee + buyLiquidityFee)) /
                    10_000;
            }

            if (stakingFees > 0) {
                super._update(from, stakingVault, stakingFees);
                amount -= stakingFees;
            }

            if (otherFees > 0) {
                super._update(from, address(this), otherFees);
                amount -= otherFees;
            }
        }
        super._update(from, to, amount);
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
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

    function _addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        address to
    ) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            to,
            block.timestamp
        );
    }

    function _swapBack() private {
        uint256 swapThreshold = swapTokensAtAmount;

        if (balanceOf(address(this)) > swapTokensAtAmount * 20) {
            swapThreshold = swapTokensAtAmount * 20;
        }

        uint256 denominator = buyLiquidityFee +
            sellLiquidityFee +
            buyOperationFee +
            sellOperationFee;

        if (denominator == 0) return;

        uint256 tokensForLiquidity = (swapThreshold *
            (buyLiquidityFee + sellLiquidityFee)) / denominator;
        uint256 tokensForOperation = (swapThreshold *
            (buyOperationFee + sellOperationFee)) / denominator;
        uint256 totalTokens = tokensForLiquidity + tokensForOperation;

        if (totalTokens == 0) return;

        _swapTokensForEth(tokensForLiquidity / 2 + tokensForOperation);

        uint256 ethBalance = address(this).balance;

        if (ethBalance > 0) {
            uint256 ethForLiquidity = ((ethBalance * tokensForLiquidity) / 2) /
                totalTokens;
            uint256 ethForOperation = (ethBalance * tokensForOperation) /
                totalTokens;

            if (ethForLiquidity > 0) {
                _addLiquidity(
                    tokensForLiquidity / 2,
                    ethForLiquidity,
                    treasuryVault
                );
            }

            if (ethForOperation > 0) {
                operationVault.sendValue(ethForOperation);
            }

            emit SwapAndLiquify(
                swapThreshold,
                ethForOperation,
                ethForLiquidity,
                tokensForLiquidity / 2
            );
        }
    }

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 operationETH,
        uint256 liquidityETH,
        uint256 liquidityTokens
    );
}
