// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ICreditLineStorage} from './interfaces/ICreditLineStorage.sol';
import {IERC20} from '../../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IStandardERC20} from '../../base/interfaces/IStandardERC20.sol';
import {
  IMintableBurnableERC20
} from '../../tokens/interfaces/IMintableBurnableERC20.sol';
import {ICreditLineController} from './interfaces/ICreditLineController.sol';
import {SynthereumInterfaces} from '../../core/Constants.sol';
import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {
  FixedPoint
} from '../../../@uma/core/contracts/common/implementation/FixedPoint.sol';
import {
  SafeERC20
} from '../../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {CreditLine} from './CreditLine.sol';
import {
  ISynthereumPriceFeed
} from '../../oracle/common/interfaces/IPriceFeed.sol';

library CreditLineLib {
  using FixedPoint for FixedPoint.Unsigned;
  using SafeERC20 for IERC20;
  using SafeERC20 for IStandardERC20;
  using SafeERC20 for IMintableBurnableERC20;
  using CreditLineLib for ICreditLineStorage.PositionData;
  using CreditLineLib for ICreditLineStorage.PositionManagerData;
  using CreditLineLib for ICreditLineStorage.FeeStatus;
  using CreditLineLib for FixedPoint.Unsigned;

  //----------------------------------------
  // Events
  //----------------------------------------

  event Deposit(address indexed sponsor, uint256 indexed collateralAmount);
  event Withdrawal(address indexed sponsor, uint256 indexed collateralAmount);
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

  event ClaimFee(
    address indexed claimer,
    uint256 feeAmount,
    uint256 totalRemainingFees
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

  event SetFeePercentage(uint256 feePercentage);
  event SetFeeRecipients(address[] feeRecipients, uint32[] feeProportions);

  //----------------------------------------
  // External functions
  //----------------------------------------

  function initialize(
    ICreditLineStorage.PositionManagerData storage self,
    ISynthereumFinder _finder,
    IStandardERC20 _collateralToken,
    IMintableBurnableERC20 _tokenCurrency,
    bytes32 _priceIdentifier,
    FixedPoint.Unsigned memory _minSponsorTokens,
    address _excessTokenBeneficiary,
    uint8 _version
  ) external {
    ISynthereumPriceFeed priceFeed =
      ISynthereumPriceFeed(
        _finder.getImplementationAddress(SynthereumInterfaces.PriceFeed)
      );

    require(
      priceFeed.isPriceSupported(_priceIdentifier),
      'Price identifier not supported'
    );
    require(
      _collateralToken.decimals() <= 18,
      'Collateral has more than 18 decimals'
    );
    require(
      _tokenCurrency.decimals() == 18,
      'Synthetic token has more or less than 18 decimals'
    );
    self.priceIdentifier = _priceIdentifier;
    self.synthereumFinder = _finder;
    self.collateralToken = _collateralToken;
    self.tokenCurrency = _tokenCurrency;
    self.minSponsorTokens = _minSponsorTokens;
    self.excessTokenBeneficiary = _excessTokenBeneficiary;
    self.version = _version;
  }

  function depositTo(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory collateralAmount,
    address sponsor
  ) external {
    require(collateralAmount.isGreaterThan(0), 'Invalid collateral amount');

    // Increase the position and global collateral balance by collateral amount.
    positionData._incrementCollateralBalances(
      globalPositionData,
      collateralAmount
    );

    emit Deposit(sponsor, collateralAmount.rawValue);

    positionManagerData.collateralToken.safeTransferFrom(
      msg.sender,
      address(this),
      collateralAmount.rawValue
    );
  }

  function withdraw(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory collateralAmount
  ) external returns (FixedPoint.Unsigned memory) {
    require(collateralAmount.isGreaterThan(0), 'Invalid collateral amount');

    // Decrement the sponsor's collateral and global collateral amounts.
    // Reverts if the resulting position is not properly collateralized
    _decrementCollateralBalancesCheckCR(
      positionData,
      globalPositionData,
      positionManagerData,
      collateralAmount
    );

    emit Withdrawal(msg.sender, collateralAmount.rawValue);

    // Move collateral currency from contract to sender.
    positionManagerData.collateralToken.safeTransfer(
      msg.sender,
      collateralAmount.rawValue
    );

    return collateralAmount;
  }

  function create(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory collateralAmount,
    FixedPoint.Unsigned memory numTokens,
    ICreditLineStorage.FeeStatus storage feeStatus
  ) external returns (FixedPoint.Unsigned memory feeAmount) {
    // Update fees status - percentage is retrieved from Credit Line Controller
    feeAmount = positionManagerData.calculateCollateralAmount(numTokens).mul(
      positionManagerData._getFeeInfo().feePercentage
    );
    positionManagerData.updateFees(feeStatus, feeAmount);

    if (positionData.tokensOutstanding.isEqual(0)) {
      require(
        _checkCollateralization(
          positionManagerData,
          collateralAmount.sub(feeAmount),
          numTokens
        ),
        'Insufficient Collateral'
      );
      require(
        numTokens.isGreaterThanOrEqual(positionManagerData.minSponsorTokens),
        'Below minimum sponsor position'
      );
      emit NewSponsor(msg.sender);
    } else {
      require(
        _checkCollateralization(
          positionManagerData,
          positionData.rawCollateral.add(collateralAmount).sub(feeAmount),
          positionData.tokensOutstanding.add(numTokens)
        ),
        'Insufficient Collateral'
      );
    }

    // Increase or decrease the position and global collateral balance by collateral amount or fee amount.
    collateralAmount.isGreaterThanOrEqual(feeAmount)
      ? positionData._incrementCollateralBalances(
        globalPositionData,
        collateralAmount.sub(feeAmount)
      )
      : positionData._decrementCollateralBalances(
        globalPositionData,
        feeAmount.sub(collateralAmount)
      );

    // Add the number of tokens created to the position's outstanding tokens and global.
    positionData.tokensOutstanding = positionData.tokensOutstanding.add(
      numTokens
    );

    globalPositionData.totalTokensOutstanding = globalPositionData
      .totalTokensOutstanding
      .add(numTokens);

    checkMintLimit(globalPositionData, positionManagerData);

    if (collateralAmount.isGreaterThan(FixedPoint.Unsigned(0))) {
      // pull collateral
      IERC20 collateralCurrency = positionManagerData.collateralToken;

      // Transfer tokens into the contract from caller
      collateralCurrency.safeTransferFrom(
        msg.sender,
        address(this),
        (collateralAmount).rawValue
      );
    }

    // mint corresponding synthetic tokens to the caller's address.
    positionManagerData.tokenCurrency.mint(msg.sender, numTokens.rawValue);

    emit PositionCreated(
      msg.sender,
      collateralAmount.rawValue,
      numTokens.rawValue,
      feeAmount.rawValue
    );
  }

  function redeem(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory numTokens,
    ICreditLineStorage.FeeStatus storage feeStatus,
    address sponsor
  )
    external
    returns (
      FixedPoint.Unsigned memory amountWithdrawn,
      FixedPoint.Unsigned memory feeAmount
    )
  {
    require(
      numTokens.isLessThanOrEqual(positionData.tokensOutstanding),
      'Invalid token amount'
    );

    FixedPoint.Unsigned memory collateralRedeemed =
      positionData.rawCollateral.mul(numTokens).div(
        positionData.tokensOutstanding
      );

    // Update fee status
    feeAmount = positionManagerData.calculateCollateralAmount(numTokens).mul(
      positionManagerData._getFeeInfo().feePercentage
    );
    positionManagerData.updateFees(feeStatus, feeAmount);

    // If redemption returns all tokens the sponsor has then we can delete their position. Else, downsize.
    if (positionData.tokensOutstanding.isEqual(numTokens)) {
      positionData._deleteSponsorPosition(globalPositionData, sponsor);
    } else {
      // Decrement the sponsor's collateral and global collateral amounts.
      positionData._decrementCollateralBalances(
        globalPositionData,
        collateralRedeemed
      );

      // Decrease the sponsors position tokens size. Ensure it is above the min sponsor size.
      FixedPoint.Unsigned memory newTokenCount =
        positionData.tokensOutstanding.sub(numTokens);
      require(
        newTokenCount.isGreaterThanOrEqual(
          positionManagerData.minSponsorTokens
        ),
        'Below minimum sponsor position'
      );
      positionData.tokensOutstanding = newTokenCount;
      // Update the totalTokensOutstanding after redemption.
      globalPositionData.totalTokensOutstanding = globalPositionData
        .totalTokensOutstanding
        .sub(numTokens);
    }
    // adjust the fees from collateral to withdraws
    amountWithdrawn = collateralRedeemed.sub(feeAmount);

    // transfer collateral to user
    IERC20 collateralCurrency = positionManagerData.collateralToken;

    {
      collateralCurrency.safeTransfer(msg.sender, amountWithdrawn.rawValue);

      // Pull and burn callers synthetic tokens.
      positionManagerData.tokenCurrency.safeTransferFrom(
        msg.sender,
        address(this),
        numTokens.rawValue
      );
      positionManagerData.tokenCurrency.burn(numTokens.rawValue);
    }

    emit Redeem(
      msg.sender,
      amountWithdrawn.rawValue,
      numTokens.rawValue,
      feeAmount.rawValue
    );
  }

  function repay(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory numTokens,
    ICreditLineStorage.FeeStatus storage feeStatus
  ) external returns (FixedPoint.Unsigned memory feeAmount) {
    require(
      numTokens.isLessThanOrEqual(positionData.tokensOutstanding),
      'Invalid token amount'
    );

    // Decrease the sponsors position tokens size. Ensure it is above the min sponsor size.
    FixedPoint.Unsigned memory newTokenCount =
      positionData.tokensOutstanding.sub(numTokens);
    require(
      newTokenCount.isGreaterThanOrEqual(positionManagerData.minSponsorTokens),
      'Below minimum sponsor position'
    );

    // Update fee status
    feeAmount = positionManagerData.calculateCollateralAmount(numTokens).mul(
      positionManagerData._getFeeInfo().feePercentage
    );
    positionManagerData.updateFees(feeStatus, feeAmount);

    // update position
    positionData.tokensOutstanding = newTokenCount;
    _decrementCollateralBalances(positionData, globalPositionData, feeAmount);

    // Update the totalTokensOutstanding after redemption.
    globalPositionData.totalTokensOutstanding = globalPositionData
      .totalTokensOutstanding
      .sub(numTokens);

    // Transfer the tokens back from the sponsor and burn them.
    positionManagerData.tokenCurrency.safeTransferFrom(
      msg.sender,
      address(this),
      numTokens.rawValue
    );
    positionManagerData.tokenCurrency.burn(numTokens.rawValue);

    emit Repay(
      msg.sender,
      numTokens.rawValue,
      newTokenCount.rawValue,
      feeAmount.rawValue
    );
  }

  function liquidate(
    ICreditLineStorage.PositionData storage positionToLiquidate,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    FixedPoint.Unsigned calldata numSynthTokens
  )
    external
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    // to avoid stack too deep
    ICreditLineStorage.ExecuteLiquidationData memory executeLiquidationData;

    // make sure position is undercollateralised
    require(
      !positionManagerData._checkCollateralization(
        positionToLiquidate.rawCollateral,
        positionToLiquidate.tokensOutstanding
      ),
      'Position is properly collateralised'
    );

    // calculate tokens to liquidate
    executeLiquidationData.tokensToLiquidate.rawValue = positionToLiquidate
      .tokensOutstanding
      .isGreaterThan(numSynthTokens)
      ? numSynthTokens.rawValue
      : positionToLiquidate.tokensOutstanding.rawValue;

    // calculate collateral value of those tokens
    executeLiquidationData.collateralValueLiquidatedTokens = positionManagerData
      .calculateCollateralAmount(executeLiquidationData.tokensToLiquidate);

    // calculate proportion of collateral liquidated from position
    executeLiquidationData.collateralLiquidated = executeLiquidationData
      .tokensToLiquidate
      .div(positionToLiquidate.tokensOutstanding)
      .mul(positionToLiquidate.rawCollateral);

    // compute final liquidation outcome
    FixedPoint.Unsigned memory liquidatorReward;
    if (
      executeLiquidationData.collateralLiquidated.isGreaterThan(
        executeLiquidationData.collateralValueLiquidatedTokens
      )
    ) {
      // position is still capitalised - liquidator profits
      executeLiquidationData.liquidatorReward = (
        executeLiquidationData.collateralLiquidated.sub(
          executeLiquidationData.collateralValueLiquidatedTokens
        )
      )
        .mul(positionManagerData._getLiquidationReward());
      executeLiquidationData.collateralLiquidated = executeLiquidationData
        .collateralValueLiquidatedTokens
        .add(liquidatorReward);
    } else {
      // undercapitalised - take min between position total collateral and value of burned tokens - liquidator don't make profit
      executeLiquidationData.collateralLiquidated = FixedPoint.min(
        executeLiquidationData.collateralValueLiquidatedTokens,
        positionToLiquidate.rawCollateral
      );
    }

    // reduce position
    positionToLiquidate._reducePosition(
      globalPositionData,
      executeLiquidationData.tokensToLiquidate,
      executeLiquidationData.collateralLiquidated
    );

    // transfer tokens from liquidator to here and burn them
    _burnLiquidatedTokens(
      positionManagerData,
      msg.sender,
      executeLiquidationData.tokensToLiquidate.rawValue
    );

    // pay sender with collateral unlocked + rewards
    positionManagerData.collateralToken.safeTransfer(
      msg.sender,
      executeLiquidationData.collateralLiquidated.rawValue
    );

    // return values
    return (
      executeLiquidationData.collateralLiquidated.rawValue,
      executeLiquidationData.tokensToLiquidate.rawValue,
      executeLiquidationData.liquidatorReward.rawValue
    );
  }

  function settleEmergencyShutdown(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) external returns (FixedPoint.Unsigned memory amountWithdrawn) {
    // Get caller's tokens balance
    FixedPoint.Unsigned memory tokensToRedeem =
      FixedPoint.Unsigned(
        positionManagerData.tokenCurrency.balanceOf(msg.sender)
      );

    // calculate amount of underlying collateral entitled to them, with oracle emergency price
    FixedPoint.Unsigned memory totalRedeemableCollateral =
      tokensToRedeem.mul(positionManagerData.emergencyShutdownPrice);

    // If the caller is a sponsor with outstanding collateral they are also entitled to their excess collateral after their debt.
    if (positionData.rawCollateral.isGreaterThan(0)) {
      // Calculate the underlying entitled to a token sponsor. This is collateral - debt
      FixedPoint.Unsigned memory tokenDebtValueInCollateral =
        positionData.tokensOutstanding.mul(
          positionManagerData.emergencyShutdownPrice
        );

      require(
        tokenDebtValueInCollateral.isLessThan(positionData.rawCollateral),
        'You dont have free collateral to withdraw'
      );

      // Add the number of redeemable tokens for the sponsor to their total redeemable collateral.
      totalRedeemableCollateral = totalRedeemableCollateral.add(
        positionData.rawCollateral.sub(tokenDebtValueInCollateral)
      );

      CreditLine(address(this)).deleteSponsorPosition(msg.sender);
      emit EndedSponsorPosition(msg.sender);
    }

    // Take the min of the remaining collateral and the collateral "owed". If the contract is undercapitalized,
    // the caller will get as much collateral as the contract can pay out.
    amountWithdrawn = FixedPoint.min(
      globalPositionData.rawTotalPositionCollateral,
      totalRedeemableCollateral
    );

    // Decrement total contract collateral and outstanding debt.
    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .sub(amountWithdrawn);
    globalPositionData.totalTokensOutstanding = globalPositionData
      .totalTokensOutstanding
      .sub(tokensToRedeem);

    emit SettleEmergencyShutdown(
      msg.sender,
      amountWithdrawn.rawValue,
      tokensToRedeem.rawValue
    );

    // Transfer tokens & collateral and burn the redeemed tokens.
    positionManagerData.collateralToken.safeTransfer(
      msg.sender,
      amountWithdrawn.rawValue
    );
    positionManagerData.tokenCurrency.safeTransferFrom(
      msg.sender,
      address(this),
      tokensToRedeem.rawValue
    );
    positionManagerData.tokenCurrency.burn(tokensToRedeem.rawValue);
  }

  /**
   * @notice Withdraw fees gained by the sender
   * @param self Data type the library is attached to
   * @param feeStatus Actual status of fee gained (see FeeStatus struct)
   * @return feeClaimed Amount of fee claimed
   */
  function claimFee(
    ICreditLineStorage.PositionManagerData storage self,
    ICreditLineStorage.FeeStatus storage feeStatus
  ) external returns (uint256 feeClaimed) {
    // Fee to claim
    FixedPoint.Unsigned memory _feeClaimed = feeStatus.feeGained[msg.sender];

    // Check that fee is available
    require(_feeClaimed.isGreaterThanOrEqual(0), 'No fee to claim');

    // Update fee status
    delete feeStatus.feeGained[msg.sender];

    FixedPoint.Unsigned memory _totalRemainingFees =
      feeStatus.totalFeeAmount.sub(_feeClaimed);

    feeStatus.totalFeeAmount = _totalRemainingFees;

    // Transfer amount to the sender
    feeClaimed = _feeClaimed.rawValue;

    self.collateralToken.safeTransfer(msg.sender, _feeClaimed.rawValue);

    emit ClaimFee(msg.sender, feeClaimed, _totalRemainingFees.rawValue);
  }

  /**
   * @notice Update fee gained by the fee recipients
   * @param feeStatus Actual status of fee gained to be withdrawn
   * @param feeAmount Collateral fee charged
   */
  function updateFees(
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    ICreditLineStorage.FeeStatus storage feeStatus,
    FixedPoint.Unsigned memory feeAmount
  ) internal {
    FixedPoint.Unsigned memory feeCharged;

    ICreditLineStorage.Fee memory feeStruct = positionManagerData._getFeeInfo();
    address[] memory feeRecipients = feeStruct.feeRecipients;
    uint32[] memory feeProportions = feeStruct.feeProportions;
    uint256 totalFeeProportions = feeStruct.totalFeeProportions;
    uint256 numberOfRecipients = feeRecipients.length;
    mapping(address => FixedPoint.Unsigned) storage feeGained =
      feeStatus.feeGained;

    for (uint256 i = 0; i < numberOfRecipients - 1; i++) {
      address feeRecipient = feeRecipients[i];
      FixedPoint.Unsigned memory feeReceived =
        FixedPoint.Unsigned(
          (feeAmount.rawValue * feeProportions[i]) / totalFeeProportions
        );
      feeGained[feeRecipient] = feeGained[feeRecipient].add(feeReceived);
      feeCharged = feeCharged.add(feeReceived);
    }

    address lastRecipient = feeRecipients[numberOfRecipients - 1];

    feeGained[lastRecipient] = feeGained[lastRecipient].add(feeAmount).sub(
      feeCharged
    );

    feeStatus.totalFeeAmount = feeStatus.totalFeeAmount.add(feeAmount);
  }

  function trimExcess(
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.FeeStatus storage feeStatus,
    IERC20 token
  ) external returns (FixedPoint.Unsigned memory amount) {
    FixedPoint.Unsigned memory balance =
      FixedPoint.Unsigned(token.balanceOf(address(this)));
    if (address(token) == address(positionManagerData.collateralToken)) {
      // If it is the collateral currency, send only the amount that the contract is not tracking (ie minus fees and positions)
      balance.isGreaterThan(
        globalPositionData.rawTotalPositionCollateral.sub(
          feeStatus.totalFeeAmount
        )
      )
        ? amount = balance
          .sub(globalPositionData.rawTotalPositionCollateral)
          .sub(feeStatus.totalFeeAmount)
        : amount = FixedPoint.Unsigned(0);
    } else {
      // If it's not the collateral currency, send the entire balance.
      amount = balance;
    }
    token.safeTransfer(
      positionManagerData.excessTokenBeneficiary,
      amount.rawValue
    );
  }

  //Calls to the CreditLine controller
  function capMintAmount(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) external view returns (FixedPoint.Unsigned memory capMint) {
    capMint = positionManagerData._getCapMintAmount();
  }

  function liquidationRewardPercentage(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) external view returns (FixedPoint.Unsigned memory liqRewardPercentage) {
    liqRewardPercentage = positionManagerData._getLiquidationReward();
  }

  function feeInfo(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) external view returns (ICreditLineStorage.Fee memory fee) {
    fee = positionManagerData._getFeeInfo();
  }

  function collateralRequirement(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) external view returns (FixedPoint.Unsigned memory) {
    return positionManagerData._getCollateralRequirement();
  }

  //----------------------------------------
  // Internal functions
  //----------------------------------------
  function _burnLiquidatedTokens(
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    address liquidator,
    uint256 amount
  ) internal {
    positionManagerData.tokenCurrency.safeTransferFrom(
      liquidator,
      address(this),
      amount
    );
    positionManagerData.tokenCurrency.burn(amount);
  }

  function _incrementCollateralBalances(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    FixedPoint.Unsigned memory collateralAmount
  ) internal {
    positionData.rawCollateral = positionData.rawCollateral.add(
      collateralAmount
    );
    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .add(collateralAmount);
  }

  function _decrementCollateralBalances(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    FixedPoint.Unsigned memory collateralAmount
  ) internal {
    positionData.rawCollateral = positionData.rawCollateral.sub(
      collateralAmount
    );
    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .sub(collateralAmount);
  }

  //remove the withdrawn collateral from the position and then check its CR
  function _decrementCollateralBalancesCheckCR(
    ICreditLineStorage.PositionData storage positionData,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory collateralAmount
  ) internal {
    FixedPoint.Unsigned memory newRawCollateral =
      positionData.rawCollateral.sub(collateralAmount);

    positionData.rawCollateral = newRawCollateral;

    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .sub(collateralAmount);

    require(
      _checkCollateralization(
        positionManagerData,
        newRawCollateral,
        positionData.tokensOutstanding
      ),
      'CR is not sufficiently high after the withdraw - try less amount'
    );
  }

  // Deletes a sponsor's position and updates global counters. Does not make any external transfers.
  function _deleteSponsorPosition(
    ICreditLineStorage.PositionData storage positionToLiquidate,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    address sponsor
  ) internal returns (FixedPoint.Unsigned memory) {
    // Remove the collateral and outstanding from the overall total position.
    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .sub(positionToLiquidate.rawCollateral);
    globalPositionData.totalTokensOutstanding = globalPositionData
      .totalTokensOutstanding
      .sub(positionToLiquidate.tokensOutstanding);

    // delete position entry from storage
    CreditLine(address(this)).deleteSponsorPosition(sponsor);

    emit EndedSponsorPosition(sponsor);

    // Return unlocked amount of collateral
    return positionToLiquidate.rawCollateral;
  }

  function _reducePosition(
    ICreditLineStorage.PositionData storage positionToLiquidate,
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    FixedPoint.Unsigned memory tokensToLiquidate,
    FixedPoint.Unsigned memory collateralToLiquidate
  ) internal {
    // reduce position
    positionToLiquidate.tokensOutstanding = positionToLiquidate
      .tokensOutstanding
      .sub(tokensToLiquidate);
    positionToLiquidate.rawCollateral = positionToLiquidate.rawCollateral.sub(
      collateralToLiquidate
    );

    // update global position data
    globalPositionData.totalTokensOutstanding = globalPositionData
      .totalTokensOutstanding
      .sub(tokensToLiquidate);
    globalPositionData.rawTotalPositionCollateral = globalPositionData
      .rawTotalPositionCollateral
      .sub(collateralToLiquidate);
  }

  function _checkCollateralization(
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory collateral,
    FixedPoint.Unsigned memory numTokens
  ) internal view returns (bool) {
    // get oracle price
    FixedPoint.Unsigned memory oraclePrice =
      _getOraclePrice(positionManagerData);

    uint256 collateralDecimals =
      getCollateralDecimals(positionManagerData.collateralToken);

    // calculate the min collateral of numTokens with chainlink
    FixedPoint.Unsigned memory thresholdValue =
      numTokens.mul(oraclePrice).div(10**(18 - collateralDecimals));

    thresholdValue = thresholdValue.mul(
      positionManagerData._getCollateralRequirement()
    );

    return collateral.isGreaterThanOrEqual(thresholdValue);
  }

  // Check new total number of tokens does not overcome mint limit
  function checkMintLimit(
    ICreditLineStorage.GlobalPositionData storage globalPositionData,
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view {
    require(
      globalPositionData.totalTokensOutstanding.isLessThanOrEqual(
        positionManagerData._getCapMintAmount()
      ),
      'Total amount minted overcomes mint limit'
    );
  }

  /**
   * @notice Retrun the on-chain oracle price for a pair
   * @return priceRate Latest rate of the pair
   */
  function _getOraclePrice(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (FixedPoint.Unsigned memory priceRate) {
    ISynthereumPriceFeed priceFeed =
      ISynthereumPriceFeed(
        positionManagerData.synthereumFinder.getImplementationAddress(
          SynthereumInterfaces.PriceFeed
        )
      );
    priceRate = FixedPoint.Unsigned(
      priceFeed.getLatestPrice(positionManagerData.priceIdentifier)
    );
  }

  /// @notice calls CreditLineController to retrieve liquidation reward percentage
  function _getLiquidationReward(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (FixedPoint.Unsigned memory liqRewardPercentage) {
    liqRewardPercentage = FixedPoint.Unsigned(
      positionManagerData
        .getCreditLineController()
        .getLiquidationRewardPercentage(address(this))
    );
  }

  function _getFeeInfo(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (ICreditLineStorage.Fee memory fee) {
    fee = positionManagerData.getCreditLineController().getFeeInfo(
      address(this)
    );
  }

  function _getCollateralRequirement(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (FixedPoint.Unsigned memory) {
    return
      FixedPoint.Unsigned(
        positionManagerData.getCreditLineController().getCollateralRequirement(
          address(this)
        )
      );
  }

  // Get mint amount limit from CreditLineController
  function _getCapMintAmount(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (FixedPoint.Unsigned memory capMint) {
    capMint = FixedPoint.Unsigned(
      positionManagerData.getCreditLineController().getCapMintAmount(
        address(this)
      )
    );
  }

  // Get self-minting controller instance
  function getCreditLineController(
    ICreditLineStorage.PositionManagerData storage positionManagerData
  ) internal view returns (ICreditLineController creditLineController) {
    creditLineController = ICreditLineController(
      positionManagerData.synthereumFinder.getImplementationAddress(
        SynthereumInterfaces.CreditLineController
      )
    );
  }

  function getCollateralDecimals(IStandardERC20 collateralToken)
    internal
    view
    returns (uint256 decimals)
  {
    decimals = collateralToken.decimals();
  }

  /**
   * @notice Calculate collateral amount starting from an amount of synthtic token
   * @param numTokens Amount of synthetic tokens from which you want to calculate collateral amount
   * @return collateralAmount Amount of collateral after on-chain oracle conversion
   */
  function calculateCollateralAmount(
    ICreditLineStorage.PositionManagerData storage positionManagerData,
    FixedPoint.Unsigned memory numTokens
  ) internal view returns (FixedPoint.Unsigned memory collateralAmount) {
    collateralAmount = numTokens.mul(_getOraclePrice(positionManagerData)).div(
      10**(18 - getCollateralDecimals(positionManagerData.collateralToken))
    );
  }
}
