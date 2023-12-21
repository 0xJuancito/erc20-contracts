// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IUniswapV3LiquidityManager {

    function addDEXLiquidity(uint256 mintedVolTokenAmount, uint256 usdcAmount) external returns (uint256 addedUDSCAmount, uint256 addedVolTokenAmount);
    function removeDEXLiquidity(uint256 partOfAmount, uint256 totalAmount) external returns (uint256 removedVolTokensAmount, uint256 dexRemovedUSDC);
    function burnPosition() external;
    function setRange(uint160 minPriceSqrtX96, uint160 maxPriceSqrtX96) external;
    function collectFees() external returns (uint256 volTokenAmount, uint256 usdcAmount);
    function updatePoolPrice(uint256 volTokenPositionBalance) external;
    function hasPosition() external view returns (bool);
    function calculateDEXLiquidityUSDCAmount(uint256 tokenAmount) external view returns (uint256 usdcDEXAmount);
    function calculateArbitrageAmount(uint256 volTokenBalance) external view returns (uint256 usdcAmount);

    struct CalculateDepositParams {
        uint256 depositAmount;
        uint256 cviValue;
        uint256 intrinsicVolTokenPrice;
        uint256 maxCVIValue;
        uint256 extraLiquidityPercentage;
    }

    function calculateDepositMintVolTokensUSDCAmount(CalculateDepositParams calldata params) external view returns (uint256 mintVolTokenUDSCAmount);
    function getReserves() external view returns (uint256 volTokenAmount, uint256 dexUSDCByVolToken, uint256 usdcAmount);
    function getVaultDEXVolTokens() external view returns (uint256 vaultDEXVolTokens);
    function getVaultDEXBalance(uint256 intrinsicDEXVolTokenBalance, uint256 dexUSDCAmount) external view returns (uint256 vaultIntrinsicDEXVolTokenBalance, uint256 vaultDEXUSDCAmount);
    function getDexPrice() external view returns (uint256);
}

