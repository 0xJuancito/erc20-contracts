// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


// AddLiquidityHelper, allows anyone to add or remove Arcadium liquidity tax free
// Also allows the Arcadium Token to do buy backs tax free via an external contract.
contract AddLiquidityHelper is ReentrancyGuard, Ownable {
    using SafeERC20 for ERC20;

    address public arcadiumAddress;

    IUniswapV2Router02 public immutable arcadiumSwapRouter;
    // The trading pair
    address public arcadiumSwapPair;

    // To receive ETH when swapping
    receive() external payable {}

    event SetArcadiumAddresses(address arcadiumAddress, address arcadiumSwapPair);

    /**
     * @notice Constructs the AddLiquidityHelper contract.
     */
    constructor(address _router) public  {
        require(_router != address(0), "_router is the zero address");
        arcadiumSwapRouter = IUniswapV2Router02(_router);
    }

    function arcadiumETHLiquidityWithBuyBack(address lpHolder) external payable nonReentrant {
        require(msg.sender == arcadiumAddress, "can only be used by the arcadium token!");

        (uint256 res0, uint256 res1, ) = IUniswapV2Pair(arcadiumSwapPair).getReserves();

        if (res0 != 0 && res1 != 0) {
            // making weth res0
            if (IUniswapV2Pair(arcadiumSwapPair).token0() == arcadiumAddress)
                (res1, res0) = (res0, res1);

            uint256 contractTokenBalance = ERC20(arcadiumAddress).balanceOf(address(this));

            // calculate how much eth is needed to use all of contractTokenBalance
            // also boost precision a tad.
            uint256 totalETHNeeded = (res0 * contractTokenBalance) / res1;

            uint256 existingETH = address(this).balance;

            uint256 unmatchedArcadium = 0;

            if (existingETH < totalETHNeeded) {
                // calculate how much arcadium will match up with our existing eth.
                uint256 matchedArcadium = (res1 * existingETH) / res0;
                if (contractTokenBalance >= matchedArcadium)
                    unmatchedArcadium = contractTokenBalance - matchedArcadium;
            } else if (existingETH > totalETHNeeded) {
                // use excess eth for arcadium buy back
                uint256 excessETH = existingETH - totalETHNeeded;

                if (excessETH / 2 > 0) {
                    // swap half of the excess eth for lp to be balanced
                    swapETHForTokens(excessETH / 2, arcadiumAddress);
                }
            }

            uint256 unmatchedArcadiumToSwap = unmatchedArcadium / 2;

            // swap tokens for ETH
            if (unmatchedArcadiumToSwap > 0)
                swapTokensForEth(arcadiumAddress, unmatchedArcadiumToSwap);

            uint256 arcadiumBalance = ERC20(arcadiumAddress).balanceOf(address(this));

            // approve token transfer to cover all possible scenarios
            ERC20(arcadiumAddress).approve(address(arcadiumSwapRouter), arcadiumBalance);

            // add the liquidity
            arcadiumSwapRouter.addLiquidityETH{value: address(this).balance}(
                arcadiumAddress,
                arcadiumBalance,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                lpHolder,
                block.timestamp
            );

        }

        if (address(this).balance > 0) {
            // not going to require/check return value of this transfer as reverting behaviour is undesirable.
            payable(address(msg.sender)).call{value: address(this).balance}("");
        }

        if (ERC20(arcadiumAddress).balanceOf(address(this)) > 0)
            ERC20(arcadiumAddress).transfer(msg.sender, ERC20(arcadiumAddress).balanceOf(address(this)));
    }

    function addArcadiumETHLiquidity(uint256 nativeAmount) external payable nonReentrant {
        require(msg.value > 0, "!sufficient funds");

        ERC20(arcadiumAddress).safeTransferFrom(msg.sender, address(this), nativeAmount);

        // approve token transfer to cover all possible scenarios
        ERC20(arcadiumAddress).approve(address(arcadiumSwapRouter), nativeAmount);

        // add the liquidity
        arcadiumSwapRouter.addLiquidityETH{value: msg.value}(
            arcadiumAddress,
            nativeAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

        if (address(this).balance > 0) {
            // not going to require/check return value of this transfer as reverting behaviour is undesirable.
            payable(address(msg.sender)).call{value: address(this).balance}("");
        }

        if (ERC20(arcadiumAddress).balanceOf(address(this)) > 0)
            ERC20(arcadiumAddress).transfer(msg.sender, ERC20(arcadiumAddress).balanceOf(address(this)));
    }

    function addArcadiumLiquidity(address baseTokenAddress, uint256 baseAmount, uint256 nativeAmount) external nonReentrant {
        ERC20(baseTokenAddress).safeTransferFrom(msg.sender, address(this), baseAmount);
        ERC20(arcadiumAddress).safeTransferFrom(msg.sender, address(this), nativeAmount);

        // approve token transfer to cover all possible scenarios
        ERC20(baseTokenAddress).approve(address(arcadiumSwapRouter), baseAmount);
        ERC20(arcadiumAddress).approve(address(arcadiumSwapRouter), nativeAmount);

        // add the liquidity
        arcadiumSwapRouter.addLiquidity(
            baseTokenAddress,
            arcadiumAddress,
            baseAmount,
            nativeAmount ,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );

        if (ERC20(baseTokenAddress).balanceOf(address(this)) > 0)
            ERC20(baseTokenAddress).safeTransfer(msg.sender, ERC20(baseTokenAddress).balanceOf(address(this)));

        if (ERC20(arcadiumAddress).balanceOf(address(this)) > 0)
            ERC20(arcadiumAddress).transfer(msg.sender, ERC20(arcadiumAddress).balanceOf(address(this)));
    }

    function removeArcadiumLiquidity(address baseTokenAddress, uint256 liquidity) external nonReentrant {
        address lpTokenAddress = IUniswapV2Factory(arcadiumSwapRouter.factory()).getPair(baseTokenAddress, arcadiumAddress);
        require(lpTokenAddress != address(0), "pair hasn't been created yet, so can't remove liquidity!");

        ERC20(lpTokenAddress).safeTransferFrom(msg.sender, address(this), liquidity);
        // approve token transfer to cover all possible scenarios
        ERC20(lpTokenAddress).approve(address(arcadiumSwapRouter), liquidity);

        // add the liquidity
        arcadiumSwapRouter.removeLiquidity(
            baseTokenAddress,
            arcadiumAddress,
            liquidity,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );
    }

    /// @dev Swap tokens for eth
    function swapTokensForEth(address saleTokenAddress, uint256 tokenAmount) internal {
        // generate the arcadiumSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = saleTokenAddress;
        path[1] = arcadiumSwapRouter.WETH();

        ERC20(saleTokenAddress).approve(address(arcadiumSwapRouter), tokenAmount);

        // make the swap
        arcadiumSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }


    function swapETHForTokens(uint256 ethAmount, address wantedTokenAddress) internal {
        require(address(this).balance >= ethAmount, "insufficient matic provided!");
        require(wantedTokenAddress != address(0), "wanted token address can't be the zero address!");

        // generate the arcadiumSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = arcadiumSwapRouter.WETH();
        path[1] = wantedTokenAddress;

        // make the swap
        arcadiumSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0,
            path,
            // cannot send tokens to the token contract of the same type as the output token
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev set the arcadium address.
     * Can only be called by the current owner.
     */
    function setArcadiumAddress(address _arcadiumAddress) external onlyOwner {
        require(_arcadiumAddress != address(0), "_arcadiumAddress is the zero address");
        require(arcadiumAddress == address(0), "arcadiumAddress already set!");

        arcadiumAddress = _arcadiumAddress;

        arcadiumSwapPair = IUniswapV2Factory(arcadiumSwapRouter.factory()).getPair(arcadiumAddress, arcadiumSwapRouter.WETH());

        require(address(arcadiumSwapPair) != address(0), "matic pair !exist");

        emit SetArcadiumAddresses(arcadiumAddress, arcadiumSwapPair);
    }
}
