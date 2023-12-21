// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import {IERC20} from '../../../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  FixedPoint
} from '../../../../@uma/core/contracts/common/implementation/FixedPoint.sol';
import {ISynthereumFinder} from '../../../core/interfaces/IFinder.sol';

/**
 * @title SelfMintingPerpetualMultiParty Contract.
 * @notice Convenient wrapper for Liquidatable.
 */
interface ISelfMintingMultiParty {
  //----------------------------------------
  // Events
  //----------------------------------------
  event Deposit(address indexed sponsor, uint256 indexed collateralAmount);
  event Withdrawal(address indexed sponsor, uint256 indexed collateralAmount);
  event RequestWithdrawal(
    address indexed sponsor,
    uint256 indexed collateralAmount
  );
  event RequestWithdrawalExecuted(
    address indexed sponsor,
    uint256 indexed collateralAmount
  );
  event RequestWithdrawalCanceled(
    address indexed sponsor,
    uint256 indexed collateralAmount
  );
  event PositionCreated(
    address indexed sponsor,
    uint256 indexed collateralAmount,
    uint256 indexed tokenAmount,
    uint256 feeAmount
  );
  event NewSponsor(address indexed sponsor);
  event EndedSponsorPosition(address indexed sponsor);
  event Redeem(
    address indexed sponsor,
    uint256 indexed collateralAmount,
    uint256 indexed tokenAmount,
    uint256 feeAmount
  );
  event Repay(
    address indexed sponsor,
    uint256 indexed numTokensRepaid,
    uint256 indexed newTokenCount,
    uint256 feeAmount
  );
  event EmergencyShutdown(address indexed caller, uint256 shutdownTimestamp);
  event SettleEmergencyShutdown(
    address indexed caller,
    uint256 indexed collateralReturned,
    uint256 indexed tokensBurned
  );

  struct PositionData {
    FixedPoint.Unsigned tokensOutstanding;
    uint256 withdrawalRequestPassTimestamp;
    FixedPoint.Unsigned withdrawalRequestAmount;
    FixedPoint.Unsigned rawCollateral;
  }

  struct LiquidatableData {
    FixedPoint.Unsigned rawLiquidationCollateral;
    uint256 liquidationLiveness;
    FixedPoint.Unsigned collateralRequirement;
    FixedPoint.Unsigned disputeBondPct;
    FixedPoint.Unsigned sponsorDisputeRewardPct;
    FixedPoint.Unsigned disputerDisputeRewardPct;
  }

  //----------------------------------------
  // External functions
  //----------------------------------------
  /**
   * @notice Transfers `collateralAmount` of `feePayerData.collateralCurrency` into the caller's position.
   * @dev Increases the collateralization level of a position after creation. This contract must be approved to spend
   * at least `collateralAmount` of `feePayerData.collateralCurrency`.
   * @param collateralAmount total amount of collateral tokens to be sent to the sponsor's position.
   */
  function deposit(uint256 collateralAmount) external;

  /**
   * @notice Transfers `collateralAmount` of `feePayerData.collateralCurrency` from the sponsor's position to the sponsor.
   * @dev Reverts if the withdrawal puts this position's collateralization ratio below the global collateralization
   * ratio. In that case, use `requestWithdrawal`. Might not withdraw the full requested amount to account for precision loss.
   * @param collateralAmount is the amount of collateral to withdraw.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function withdraw(uint256 collateralAmount)
    external
    returns (uint256 amountWithdrawn);

  /**
   * @notice Starts a withdrawal request that, if passed, allows the sponsor to withdraw` from their position.
   * @dev The request will be pending for `withdrawalLiveness`, during which the position can be liquidated.
   * @param collateralAmount the amount of collateral requested to withdraw
   */
  function requestWithdrawal(uint256 collateralAmount) external;

  /**
   * @notice After a passed withdrawal request (i.e., by a call to `requestWithdrawal` and waiting
   * `withdrawalLiveness`), withdraws `positionData.withdrawalRequestAmount` of collateral currency.
   * @dev Might not withdraw the full requested amount in order to account for precision loss or if the full requested
   * amount exceeds the collateral in the position (due to paying fees).
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function withdrawPassedRequest() external returns (uint256 amountWithdrawn);

  /**
   * @notice Cancels a pending withdrawal request.
   */
  function cancelWithdrawal() external;

  /**
   * @notice Creates tokens by creating a new position or by augmenting an existing position. Pulls `collateralAmount
   * ` into the sponsor's position and mints `numTokens` of `tokenCurrency`.
   * @dev Can only be called by a token sponsor. Might not mint the full proportional amount of collateral
   * in order to account for precision loss. This contract must be approved to spend at least `collateralAmount` of
   * `collateralCurrency`.
   * @param collateralAmount is the number of collateral tokens to collateralize the position with
   * @param numTokens is the number of tokens to mint from the position.
   * @param feePercentage The percentage of fee that is paid in collateralCurrency
   */
  function create(
    uint256 collateralAmount,
    uint256 numTokens,
    uint256 feePercentage
  ) external returns (uint256 daoFeeAmount);

  /**
   * @notice Burns `numTokens` of `tokenCurrency` and sends back the proportional amount of `feePayerData.collateralCurrency`.
   * @dev Can only be called by a token sponsor. Might not redeem the full proportional amount of collateral
   * in order to account for precision loss. This contract must be approved to spend at least `numTokens` of
   * `tokenCurrency`.
   * @param numTokens is the number of tokens to be burnt for a commensurate amount of collateral.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function redeem(uint256 numTokens, uint256 feePercentage)
    external
    returns (uint256 amountWithdrawn, uint256 daoFeeAmount);

  /**
   * @notice Burns `numTokens` of `tokenCurrency` to decrease sponsors position size, without sending back `feePayerData.collateralCurrency`.
   * This is done by a sponsor to increase position CR.
   * @dev Can only be called by token sponsor. This contract must be approved to spend `numTokens` of `tokenCurrency`.
   * @param numTokens is the number of tokens to be burnt for a commensurate amount of collateral.
   * @param feePercentage the fee percentage paid by the token sponsor in collateralCurrency
   */
  function repay(uint256 numTokens, uint256 feePercentage)
    external
    returns (uint256 daoFeeAmount);

  /**
   * @notice If the contract is emergency shutdown then all token holders and sponsor can redeem their tokens or
   * remaining collateral for underlying at the prevailing price defined by a DVM vote.
   * @dev This burns all tokens from the caller of `tokenCurrency` and sends back the resolved settlement value of
   * `feePayerData.collateralCurrency`. Might not redeem the full proportional amount of collateral in order to account for
   * precision loss. This contract must be approved to spend `tokenCurrency` at least up to the caller's full balance.
   * @dev This contract must have the Burner role for the `tokenCurrency`.
   * @return amountWithdrawn The actual amount of collateral withdrawn.
   */
  function settleEmergencyShutdown() external returns (uint256 amountWithdrawn);

  /**
   * @notice Premature contract settlement under emergency circumstances.
   * @dev Only the governor can call this function as they are permissioned within the `FinancialContractAdmin`.
   * Upon emergency shutdown, the contract settlement time is set to the shutdown time. This enables withdrawal
   * to occur via the `settleEmergencyShutdown` function.
   */
  function emergencyShutdown() external;

  /** @notice Remargin function
   */
  function remargin() external;

  /**
   * @notice Drains any excess balance of the provided ERC20 token to a pre-selected beneficiary.
   * @dev This will drain down to the amount of tracked collateral and drain the full balance of any other token.
   * @param token address of the ERC20 token whose excess balance should be drained.
   */
  function trimExcess(IERC20 token) external returns (uint256 amount);

  /**
   * @notice Delete a TokenSponsor position (This function can only be called by the contract itself)
   * @param sponsor address of the TokenSponsor.
   */
  function deleteSponsorPosition(address sponsor) external;

  /**
   * @notice Accessor method for a sponsor's collateral.
   * @dev This is necessary because the struct returned by the positions() method shows
   * rawCollateral, which isn't a user-readable value.
   * @param sponsor address whose collateral amount is retrieved.
   * @return collateralAmount amount of collateral within a sponsors position.
   */
  function getCollateral(address sponsor)
    external
    view
    returns (FixedPoint.Unsigned memory collateralAmount);

  /**
   * @notice Get SynthereumFinder contract address
   * @return finder SynthereumFinder contract
   */
  function synthereumFinder() external view returns (ISynthereumFinder finder);

  /**
   * @notice Get synthetic token currency
   * @return synthToken Synthetic token
   */
  function tokenCurrency() external view returns (IERC20 synthToken);

  /**
   * @notice Get synthetic token symbol
   * @return symbol Synthetic token symbol
   */
  function syntheticTokenSymbol() external view returns (string memory symbol);

  /** @notice Get the version of a self minting derivative
   * @return contractVersion Contract version
   */
  function version() external view returns (uint8 contractVersion);

  /**
   * @notice Get synthetic token price identifier registered with UMA DVM
   * @return identifier Synthetic token price identifier
   */
  function priceIdentifier() external view returns (bytes32 identifier);

  /**
   * @notice Accessor method for the total collateral stored within the SelfMintingPerpetualPositionManagerMultiParty.
   * @return totalCollateral amount of all collateral within the position manager.
   */
  function totalPositionCollateral() external view returns (uint256);

  /**
   * @notice Get the currently minted synthetic tokens from all self-minting derivatives
   * @return totalTokens Total amount of synthetic tokens minted
   */
  function totalTokensOutstanding() external view returns (uint256);

  /**
   * @notice Get the price of synthetic token set by DVM after emergencyShutdown call
   * @return Price of synthetic token
   */
  function emergencyShutdownPrice() external view returns (uint256);

  /** @notice Calculates the DAO fee based on the numTokens parameter
   * @param numTokens Number of synthetic tokens used in the transaction
   * @return rawValue The DAO fee to be paid in collateralCurrency
   */
  function calculateDaoFee(uint256 numTokens) external view returns (uint256);

  /** @notice Checks the currently set fee recipient and fee percentage for the DAO fee
   * @return feePercentage The percentage set by the DAO to be taken as a fee on each transaction
   * @return feeRecipient The DAO address that receives the fee
   */
  function daoFee()
    external
    view
    returns (uint256 feePercentage, address feeRecipient);

  /** @notice Check the current cap on self-minting synthetic tokens.
   * A cap mint amount is set in order to avoid depletion of liquidity pools,
   * by self-minting synthetic assets and redeeming collateral from the pools.
   * The cap mint amount is updateable and is based on a percentage of the currently
   * minted synthetic assets from the liquidity pools.
   * @return capMint The currently set cap amount for self-minting a synthetic token
   */
  function capMintAmount() external view returns (uint256 capMint);

  /** @notice Check the current cap on deposit of collateral into a self-minting derivative.
   * A cap deposit ratio is set in order to avoid a troll attack in which an attacker
   * can increase infinitely the GCR thus making it extremelly expensive or impossible
   * for other users to self-mint synthetic assets with a given collateral.
   * @return capDeposit The current cap deposit ratio
   */
  function capDepositRatio() external view returns (uint256 capDeposit);

  /**
   * @notice Transfers `collateralAmount` of `feePayerData.collateralCurrency` into the specified sponsor's position.
   * @dev Increases the collateralization level of a position after creation. This contract must be approved to spend
   * at least `collateralAmount` of `feePayerData.collateralCurrency`.
   * @param sponsor the sponsor to credit the deposit to.
   * @param collateralAmount total amount of collateral tokens to be sent to the sponsor's position.
   */
  function depositTo(address sponsor, uint256 collateralAmount) external;

  /** @notice Check the collateralCurrency in which fees are paid for a given self-minting derivative
   * @return collateral The collateral currency
   */
  function collateralCurrency() external view returns (IERC20 collateral);

  function positions(address tokenSponsor)
    external
    view
    returns (PositionData memory tsPosition);

  function liquidatableData()
    external
    view
    returns (LiquidatableData memory data);
}
