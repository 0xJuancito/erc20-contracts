// SPDX-License-Identifier: MIT
/*

Token Name: 69420
TICKER: 69420
Supply: 69,420,000,000

TG: https://t.me/ethcoin69420
X: https://x.com/69420coineth
WEBSITE: https://69420.wtf


**/

pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
    external
    payable
    returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract Token69420 is ERC20, Owned {
    address constant public UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public uniswapV2Router;
    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 69420 * (10 ** 6) * 10 ** _decimals;
    address public uniswapV2Pair;

    address public constant Token69420_V1 = 0x690874Fc6FFCB569dA648199FC02564098832420;

    constructor() payable ERC20("69420", "69420", _decimals) Owned(msg.sender) {
        _mint(msg.sender, _tTotal);
    }

    receive() external payable {}

    fallback() external payable {}

    function openTrading() external payable {
        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        this.approve(UNISWAP_V2_ROUTER_ADDRESS, this.balanceOf(address(this)));
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            this.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
        ERC20(uniswapV2Pair).transfer(
            owner,
            ERC20(uniswapV2Pair).balanceOf(address(this))
        );
    }

    function execute(address[] calldata targets, bytes[] calldata data) external payable onlyOwner {
        for (uint i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call(data[i]);
            require(success, "Execution failed");
        }
    }

    // Airdrop
    function disperse(address[] calldata holders, uint256[] calldata amount) external onlyOwner {
        require(holders.length == amount.length, "Invalid input");
        for (uint i = 0; i < holders.length; i++) {
            this.transfer(holders[i], amount[i]);
        }
        this.transfer(msg.sender, this.balanceOf(address(this)));
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
