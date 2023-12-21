// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/IAccessControl.sol";

import "./IMToken.sol";
import "./ILinkageLeaf.sol";
import "./IPriceOracle.sol";

/**
 * This contract provides the liquidation functionality.
 */
interface ILiquidation is IAccessControl, ILinkageLeaf {
    event HealthyFactorLimitChanged(uint256 oldValue, uint256 newValue);
    event ReliableLiquidation(
        bool isDebtHealthy,
        address liquidator,
        address borrower,
        IMToken seizeMarket,
        IMToken repayMarket,
        uint256 seizeAmountUnderlying,
        uint256 repayAmountUnderlying
    );

    /**
     * @dev Local accountState for avoiding stack-depth limits in calculating liquidation amounts.
     */
    struct AccountLiquidationAmounts {
        uint256 accountTotalSupplyUsd;
        uint256 accountTotalCollateralUsd;
        uint256 accountPresumedTotalRepayUsd;
        uint256 accountTotalBorrowUsd;
        uint256 accountTotalCollateralUsdAfter;
        uint256 accountTotalBorrowUsdAfter;
        uint256 seizeAmount;
    }

    /**
     * @notice GET The maximum allowable value of a healthy factor after liquidation, scaled by 1e18
     */
    function healthyFactorLimit() external view returns (uint256);

    /**
     * @notice get keccak-256 hash of TRUSTED_LIQUIDATOR role
     */
    function TRUSTED_LIQUIDATOR() external view returns (bytes32);

    /**
     * @notice get keccak-256 hash of TIMELOCK role
     */
    function TIMELOCK() external view returns (bytes32);

    /**
     * @notice Liquidate insolvent debt position
     * @param seizeMarket  Market from which the account's collateral will be seized
     * @param repayMarket Market from which the account's debt will be repaid
     * @param borrower Account which is being liquidated
     * @param repayAmount Amount of debt to be repaid
     * @return (seizeAmount, repayAmount)
     * @dev RESTRICTION: Trusted liquidator only
     */
    function liquidateUnsafeLoan(
        IMToken seizeMarket,
        IMToken repayMarket,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256, uint256);

    /**
     * @notice Accrues interest for repay and seize markets
     * @param seizeMarket  Market from which the account's collateral will be seized
     * @param repayMarket Market from which the account's debt will be repaid
     */
    function accrue(IMToken seizeMarket, IMToken repayMarket) external;

    /**
     * @notice Calculates account states: total balances, seize amount, new collateral and borrow state
     * @param account_ The address of the borrower
     * @param marketAddresses An array with addresses of markets where the debtor is in
     * @param seizeMarket  Market from which the account's collateral will be seized
     * @param repayMarket Market from which the account's debt will be repaid
     * @param repayAmount Amount of debt to be repaid
     * @return accountState Struct that contains all balance parameters
     */
    function calculateLiquidationAmounts(
        address account_,
        IMToken[] memory marketAddresses,
        IMToken seizeMarket,
        IMToken repayMarket,
        uint256 repayAmount
    ) external view returns (AccountLiquidationAmounts memory);

    /**
     * @notice Sets a new value for healthyFactorLimit
     * @dev RESTRICTION: Timelock only
     */
    function setHealthyFactorLimit(uint256 newValue_) external;
}
