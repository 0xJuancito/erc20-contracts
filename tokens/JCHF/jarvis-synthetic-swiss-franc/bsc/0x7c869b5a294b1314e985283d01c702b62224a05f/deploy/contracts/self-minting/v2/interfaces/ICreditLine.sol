// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {
  FixedPoint
} from '../../../../@uma/core/contracts/common/implementation/FixedPoint.sol';
import {ISynthereumFinder} from '../../../core/interfaces/IFinder.sol';
import {IStandardERC20} from '../../../base/interfaces/IStandardERC20.sol';
import {
  ISynthereumDeployment
} from '../../../common/interfaces/IDeployment.sol';
import {
  IEmergencyShutdown
} from '../../../common/interfaces/IEmergencyShutdown.sol';
import {ICreditLineStorage} from './ICreditLineStorage.sol';
import {ITypology} from '../../../common/interfaces/ITypology.sol';

interface ICreditLine is ITypology, IEmergencyShutdown, ISynthereumDeployment {
  /**
   * @notice Transfers `collateralAmount` into the caller's position.
   * @dev Increases the collateralization level of a position after creation. This contract must be approved to spend
   * at least `collateralAmount` of collateral token
   * @param collateralAmount total amount of collateral tokens to be sent to the sponsor's position.
   */
  function deposit(uint256 collateralAmount) external;

  /**
   * @notice Transfers `collateralAmount` into the specified sponsor's position.
   * @dev Increases the collateralization level of a position after creation. This contract must be approved to spend
   * at least `collateralAmount` of collateralCurrency.
   * @param sponsor the sponsor to credit the deposit to.
   * @param collateralAmount total amount of collateral tokens to be sent to the sponsor's position.
   */
  function depositTo(address sponsor, uint256 collateralAmount) external;

  /**
   * @notice Transfers `collateralAmount` from the sponsor's position to the sponsor.
   * @dev Reverts if the withdrawal puts this position's collateralization ratio below the collateral requirement
   * @param collateralAmount is the amount of collateral to withdraw.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function withdraw(uint256 collateralAmount)
    external
    returns (uint256 amountWithdrawn);

  /**
   * @notice Pulls `collateralAmount` into the sponsor's position and mints `numTokens` of `tokenCurrency`.
   * Mints new debt tokens by creating a new position or by augmenting an existing position.
   * @dev Can only be called by a token sponsor. This contract must be approved to spend at least `collateralAmount` of
   * `collateralCurrency`.
   * @param collateralAmount is the number of collateral tokens to collateralize the position with
   * @param numTokens is the number of debt tokens to mint to sponsor.
   */
  function create(uint256 collateralAmount, uint256 numTokens)
    external
    returns (uint256 feeAmount);

  /**
   * @notice Burns `numTokens` of `tokenCurrency` and sends back the proportional amount of collateral
   * @dev Can only be called by a token sponsor- This contract must be approved to spend at least `numTokens` of
   * `tokenCurrency`.
   * @param numTokens is the number of tokens to be burnt.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   * @return feeAmount incurred fees in collateral token.
   */
  function redeem(uint256 numTokens)
    external
    returns (uint256 amountWithdrawn, uint256 feeAmount);

  /**
   * @notice Burns `numTokens` of `tokenCurrency` to decrease sponsors position size, without sending back collateral.
   * This is done by a sponsor to increase position CR.
   * @dev Can only be called by token sponsor. This contract must be approved to spend `numTokens` of `tokenCurrency`.
   * @param numTokens is the number of tokens to be burnt.
   */
  function repay(uint256 numTokens) external returns (uint256 daoFeeAmount);

  /**
   * @notice Liquidate sponsor position for an amount of synthetic tokens undercollateralized
   * @notice Revert if position is not undercollateralized
   * @param sponsor Address of sponsor to be liquidated.
   * @param maxTokensToLiquidate Max number of synthetic tokens to be liquidated
   * @return tokensLiquidated Amount of debt tokens burned
   * @return collateralLiquidated Amount of received collateral equal to the value of tokens liquidated
   * @return collateralReward Amount of received collateral as reward for the liquidation
   */
  function liquidate(address sponsor, uint256 maxTokensToLiquidate)
    external
    returns (
      uint256 tokensLiquidated,
      uint256 collateralLiquidated,
      uint256 collateralReward
    );

  /**
   * @notice When in emergency shutdown state all token holders and sponsor can redeem their tokens and
   * remaining collateral at the prevailing price defined by the on-chain oracle
   * @dev This burns all tokens from the caller of `tokenCurrency` and sends back the resolved settlement value of
   * collateral. This contract must be approved to spend `tokenCurrency` at least up to the caller's full balance.
   * @dev This contract must have the Burner role for the `tokenCurrency`.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function settleEmergencyShutdown() external returns (uint256 amountWithdrawn);

  /**
   * @notice Withdraw fees gained by the sender
   * @return feeClaimed Amount of fee claimed
   */

  function claimFee() external returns (uint256 feeClaimed);

  /**
   * @notice Checks if a sponsor position is collateralised, according to latest on-chain price
   * @param sponsor address of the TokenSponsor to check
   * @return true if position is collateralised, false if not
   */
  function isCollateralised(address sponsor) external view returns (bool);

  /**
   * @notice Returns the cap mint amount of the derivative contract
   * @return capMint cap mint amount
   */
  function getCapMintAmount() external view returns (uint256 capMint);

  /**
   * @notice Returns the liquidation rewrd percentage of the derivative contract
   * @return rewardPct liquidator reward percentage
   */
  function getLiquidationReward() external view returns (uint256 rewardPct);

  /**
   * @notice Returns the fee parameters of the derivative contract
   * @return fee Fee struct
   */
  function getFeeInfo()
    external
    view
    returns (ICreditLineStorage.Fee memory fee);

  /**
   * @notice Returns the over collateralization percentage of the derivative contract
   * @return collateralRequirement percentage of overcollateralization
   */
  function getCollateralRequirement()
    external
    view
    returns (uint256 collateralRequirement);

  /**
   * @notice Delete a TokenSponsor position. This function can only be called by the contract itself.
   * @param sponsor address of the TokenSponsor.
   */
  function deleteSponsorPosition(address sponsor) external;

  /**
   * @notice Accessor method for a sponsor's collateral.
   * @dev This is necessary because the struct returned by positions() method shows
   * rawCollateral, which isn't a user-readable value.
   * @param sponsor address whose collateral amount is retrieved.
   * @return collateralAmount amount of collateral of the sponsor's position.
   */
  function getPositionCollateral(address sponsor)
    external
    returns (FixedPoint.Unsigned memory collateralAmount);

  /**
   * @notice Get synthetic token price identifier as represented by the oracle interface
   * @return identifier Synthetic token price identifier
   */
  function priceIdentifier() external view returns (bytes32 identifier);

  /**
   * @notice Get the currently minted synthetic tokens from all self-minting derivatives
   * @return totalTokens Total amount of synthetic tokens minted
   */
  function totalTokensOutstanding() external view returns (uint256);

  /**
   * @notice Get the price of synthetic token set by DVM after emergencyShutdown call
   * @return price Price of synthetic token
   */
  function emergencyShutdownPrice() external view returns (uint256 price);
}
