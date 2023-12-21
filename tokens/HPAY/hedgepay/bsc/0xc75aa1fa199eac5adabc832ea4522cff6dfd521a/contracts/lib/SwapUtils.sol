// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SwapUtils {
    using SafeERC20 for IERC20;

    function swapExactETHForTokens(IUniswapV2Router02 router, IERC20 token, uint256 ethAmount, uint256 slippage) external returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        uint256 minAmount = 0;
        if(slippage > 0) {
            minAmount = calculateSlippage(router, path, ethAmount, slippage);
        }

        uint256[] memory amounts = router.swapExactETHForTokens{
            value: ethAmount
        }(minAmount, path, address(this), block.timestamp);

        return amounts[1];
    }

    function swapETHForTokens(IUniswapV2Router02 router, IERC20 token, uint256 ethAmount, uint256 slippage) external {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);
        
        uint256 minAmount = 0;
        if(slippage > 0) {
            minAmount = calculateSlippage(router, path, ethAmount, slippage);
        }

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(minAmount, path, address(this), block.timestamp);
    }

    function swapTokensForEth(IUniswapV2Router02 router, IERC20 token, uint256 tokenAmount, uint256 slippage) external {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        uint256 minAmount = 0;
        if(slippage > 0) {
            minAmount = calculateSlippage(router, path, tokenAmount, slippage);
        }

        token.safeIncreaseAllowance(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForTokens(IUniswapV2Router02 router, IERC20 token0, IERC20 token1, uint256 amount, uint256 slippage) external {
        address[] memory path = new address[](3);
        path[0] = address(token0);
        path[1] = router.WETH();
        path[2] = address(token1);
        
        uint256 minAmount = 0;
        if(slippage > 0) {
            minAmount = calculateSlippage(router, path, amount, slippage);
        }
        token0.safeIncreaseAllowance(address(router), amount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * Return the minimum amount expected for a given trade       
     */
    function calculateSlippage(IUniswapV2Router02  router, address[] memory path, uint256 amount, uint256 slippage) public view returns(uint256) {
        uint256 amountOut = router.getAmountsOut(amount, path)[path.length - 1];
        uint256 minAmount = amountOut - ((amountOut * slippage) / 10000);
        return minAmount;
    }
}