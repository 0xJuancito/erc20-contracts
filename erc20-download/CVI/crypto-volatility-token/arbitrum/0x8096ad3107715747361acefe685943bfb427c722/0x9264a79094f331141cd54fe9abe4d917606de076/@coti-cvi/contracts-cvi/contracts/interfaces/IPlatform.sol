// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./ICVIOracle.sol";
import "./IFeesCalculator.sol";
import "./IFeesCollector.sol";

interface IPlatform {

    struct Position {
        uint168 positionUnitsAmount;
        uint8 leverage;
        uint32 openCVIValue;
        uint32 creationTimestamp;
        uint256 originalCreationBlock;
        bytes32 referralCode;
    }

    event Deposit(address indexed account, uint256 tokenAmount, uint256 lpTokensAmount, uint256 feeAmount);
    event Withdraw(address indexed account, uint256 tokenAmount, uint256 lpTokensAmount, uint256 feeAmount);
    event OpenPosition(address indexed account, uint256 tokenAmount, uint8 leverage, uint256 feeAmount, uint256 positionUnitsAmount, uint256 cviValue, bytes32 referralCode, address indexed affiliate, uint32 affiliatePositionFeePercent, uint256 affiliateRebateAmount);
    event ClosePosition(address indexed account, uint256 tokenAmount, uint256 fundingFeesAmount, uint256 feeAmount, uint256 positionUnitsAmount, uint8 leverage, uint256 cviValue, bytes32 referralCode, address indexed affiliate, uint32 affiliatePositionFeePercent, uint256 affiliateRebateAmount);
    event MergePosition(address indexed account, uint256 tokenAmount, uint256 fundingFeesAmount, uint256 positionUnitsAmount, uint8 leverage, uint256 cviValue);
    event LiquidatePosition(address indexed positionAddress, uint256 currentPositionBalance, uint256 fundingFeesAmount, bool isBalancePositive, uint256 positionUnitsAmount, uint256 openCVIValue, uint8 leverage, uint256 liquidationCVIValue);

    function deposit(uint256 tokenAmount, uint256 minLPTokenAmount, uint32 cviValue) external returns (uint256 lpTokenAmount);
    function withdraw(uint256 tokenAmount, uint256 maxLPTokenBurnAmount, uint32 cviValue) external returns (uint256 burntAmount, uint256 withdrawnAmount);
    function withdrawLPTokens(uint256 lpTokenAmount, uint32 cviValue) external returns (uint256 burntAmount, uint256 withdrawnAmount);

    function openPositionForOwner(address owner, bytes32 referralCode, uint168 tokenAmount, uint32 maxCVI, uint32 maxBuyingPremiumFeePercentage, uint8 leverage, uint32 realTimeCVIValue) external returns (uint168 positionUnitsAmount, uint168 positionedTokenAmount, uint168 openPositionFee, uint168 buyingPremiumFee);
    function openPosition(uint168 tokenAmount, uint32 maxCVI, uint32 maxBuyingPremiumFeePercentage, uint8 leverage, bool chargeFees, uint32 closeCVIValue, uint32 cviValue) external returns (uint168 positionUnitsAmount, uint168 positionedTokenAmount, uint168 openPositionFee, uint168 buyingPremiumFee);
    function closePositionForOwner(address owner, uint168 positionUnitsAmount, uint32 minCVI, uint32 realTimeCVIValue) external returns (uint256 tokenAmount, uint256 closePositionFee, uint256 closingPremiumFee);
    function closePosition(uint168 positionUnitsAmount, uint32 minCVI, bool chargeFees, uint32 cviValue) external returns (uint256 tokenAmount, uint256 closePositionFee, uint256 closingPremiumFee);

    function liquidatePositions(address[] calldata positionOwners) external returns (uint256 finderFeeAmount);

    function calculatePositionBalance(address positionAddress) external view returns (uint256 currentPositionBalance, bool isPositive, uint168 positionUnitsAmount, uint8 leverage, uint256 fundingFees, uint256 marginDebt);
    function calculatePositionBalanceWithIndex(address positionAddress, uint32 cviValue) external view returns (uint256 currentPositionBalance, bool isPositive, uint168 positionUnitsAmount, uint8 leverage, uint256 fundingFees, uint256 marginDebt);
    function calculatePositionPendingFees(address positionAddress, uint168 positionUnitsAmount) external view returns (uint256 pendingFees);

    function totalBalance(bool withAddendum, uint32 cviValue) external view returns (uint256 balance, uint256 positionsBalance);

    function canWithdraw(uint256 tokenAmount, uint32 cviValue) external view returns (bool canWithdraw, uint256 maxLPTokensWithdrawAmount);

    function cviOracle() external view returns (ICVIOracle);
    function feesCalculator() external view returns (IFeesCalculator);
    function feesCollector() external view returns (IFeesCollector);

    function PRECISION_DECIMALS() external view returns (uint256);

    function totalPositionUnitsAmount() external view returns (uint256);
    function totalPositionsOriginalAmount() external view returns (uint256);
    function totalLeveragedTokensAmount() external view returns (uint256);
    function totalFundingFeesAmount() external view returns (uint256);
    function latestFundingFees() external view returns (uint256);
    function isReverse() external view returns (bool);

    function positions(address positionAddress) external view returns (uint168 positionUnitsAmount, uint8 leverage, uint32 openCVIValue, uint32 creationTimestamp, uint256 originalCreationBlock, bytes32 referralCode);
    function maxCVIValue() external view returns (uint32);
    function minCVIValue() external view returns (uint32);
    function maxPositionProfitPercentageCovered() external view returns (uint32);
}
