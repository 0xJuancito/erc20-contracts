// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./IThetaVaultInfo.sol";
import "./IVolatilityToken.sol";
import "./IPlatform.sol";
import "./IUniswapV3LiquidityManager.sol";

import "../external/ISwapRouter.sol";
import "../external/INonfungiblePositionManager.sol";

interface IThetaVault is IThetaVaultInfo {

    event Deposit(address indexed account, uint256 totalUSDCAmount, uint256 platformLiquidityAmount, uint256 dexVolTokenUSDCAmount, uint256 dexVolTokenAmount, uint256 dexUSDCAmount, uint256 mintedThetaTokens);
    event Withdraw(address indexed account, uint256 totalUSDCAmount, uint256 platformLiquidityAmount, uint256 dexVolTokenAmount, uint256 dexUSDCVolTokenAmount, uint256 dexUSDCAmount, uint256 burnedThetaTokens);

    function deposit(uint168 tokenAmount, uint32 balanceCVIValue) external returns (uint256 thetaTokensMinted);
    function withdraw(uint168 thetaTokenAmount, uint32 burnCVIValue, uint32 withdrawCVIValue) external returns (uint256 tokenWithdrawnAmount);

    function volToken() external view returns (IVolatilityToken);
    function platform() external view returns (IPlatform);
    function liquidityManager() external view returns (IUniswapV3LiquidityManager);
    function totalBalance(uint32 cviValue) external view returns (uint256 balance, uint256 usdcPlatformLiquidity, uint256 intrinsicDEXVolTokenBalance, uint256 volTokenPositionBalance, uint256 dexUSDCAmount, uint256 dexVolTokensAmount);
    function calculateOIBalance() external view returns (uint256 oiBalance);
    function calculateMaxOIBalance() external view returns (uint256 maxOIBalance);
}
