// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibHamachi20} from "./LibHamachi20.sol";

import {RewardToken} from "@contracts/hamachi/types/reward/RewardStorage.sol";
import {UniswapStorage} from "../types/uniswap/UniswapStorage.sol";

import {IUniswapV2Router02} from "@contracts/uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

library LibUniswap {
  event AddLiquidity(uint256 tokenAmount, uint256 ethAmount);

  bytes32 internal constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.uniswap.storage");

  function DS() internal pure returns (UniswapStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function swapTokensForEth(uint256 tokenAmount) internal {
    address router = DS().defaultRouter;
    LibHamachi20.approve(address(this), address(router), tokenAmount);

    // generate the swap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = IUniswapV2Router02(router).WETH();

    // make the swap
    IUniswapV2Router02(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 _value) internal {
    address router = DS().defaultRouter;
    LibHamachi20.approve(address(this), address(router), tokenAmount);
    IUniswapV2Router02(router).addLiquidityETH{value: _value}(
      address(this),
      tokenAmount,
      0,
      0,
      DS().liquidityWallet,
      block.timestamp
    );
    emit AddLiquidity(tokenAmount, _value);
  }

  function swapUsingV2(
    RewardToken memory rewardToken,
    uint256 _value,
    address _owner,
    uint256 _expectedOutput
  ) internal returns (bool) {
    try
      IUniswapV2Router02(rewardToken.router).swapExactETHForTokensSupportingFeeOnTransferTokens{
        value: _value
      }(_expectedOutput, rewardToken.path, _owner, block.timestamp)
    {
      return true;
    } catch {
      return false;
    }
  }

  function swapUsingV3(
    RewardToken memory rewardToken,
    uint256 _value,
    address _owner,
    uint256 _expectedOutput
  ) internal returns (bool) {
    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: rewardToken.pathV3,
      recipient: address(_owner),
      deadline: block.timestamp,
      amountIn: _value,
      amountOutMinimum: _expectedOutput
    });

    try ISwapRouter(rewardToken.router).exactInput{value: _value}(params) {
      return true;
    } catch {
      return false;
    }
  }
}
