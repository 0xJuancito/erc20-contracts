// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../LiquidityTimeLock.sol";

library PresaleUtils {
    using SafeERC20 for IERC20;
    struct PresalePhase {
        uint256 status;
        uint256 rate;
        uint256 sellRate;
        uint256 minPurchase;
        uint256 maxPurchase;
        uint256 hardCap;
        uint256 _capital;
    }

    function preValidatePurchase(PresalePhase memory phase , address beneficiary, uint256 amount) public pure {
        require(phase.status == 1 , "Phase Not started");
        require(beneficiary != address(0), "Buy: beneficiary is the zero address");
        require(amount > 0, "Buy: amount is 0");
        require(amount <= phase.maxPurchase, "have to send max: maxPurchase");
    }

    function lockLiquidity(IUniswapV2Router02 router , ERC20 token0, ERC20 token1, uint256 amount0, uint256 amount1, address lockOwner) public returns (address) {
        router.addLiquidity(
                address(token0),
                address(token1),
                amount0,
                amount1,
                0,
                0,
                address(this),
                block.timestamp + 360
        );

        IUniswapV2Factory pairFactory = IUniswapV2Factory(router.factory());
        IERC20 pair = IERC20(pairFactory.getPair(address(token0),  address(token1)));
        LiquidityTimelock liquidityLock = new LiquidityTimelock(pair, lockOwner , 90 days);
        pair.safeTransfer(address(liquidityLock), pair.balanceOf(address(this)));

        return address(liquidityLock);
    }

}
