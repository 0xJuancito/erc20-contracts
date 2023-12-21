// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ISynthereumFinder} from '../core/interfaces/IFinder.sol';
import {
  ICreditLineStorage
} from '../self-minting/v2/interfaces/ICreditLineStorage.sol';
import {
  FixedPoint
} from '../../@uma/core/contracts/common/implementation/FixedPoint.sol';

/**
 * @title SelfMintingController
 * Set capMintAmount, and fee recipient, proportions and percentage of each self-minting derivative
 */

contract CreditLineControllerMock {
  using FixedPoint for FixedPoint.Unsigned;

  bytes32 public constant MAINTAINER_ROLE = keccak256('Maintainer');

  //Describe role structure
  struct Roles {
    address admin;
    address[] maintainers;
  }

  //----------------------------------------
  // Storage
  //----------------------------------------

  ISynthereumFinder public synthereumFinder;

  mapping(address => uint256) private capMint;

  mapping(address => FixedPoint.Unsigned) private liquidationReward;

  mapping(address => FixedPoint.Unsigned)
    private overCollateralizationPercentage;

  mapping(address => ICreditLineStorage.Fee) private fee;

  //----------------------------------------
  // Constructor
  //----------------------------------------

  //----------------------------------------
  // External functions
  //----------------------------------------
  function setCollateralRequirement(
    address[] calldata selfMintingDerivatives,
    uint256[] calldata overcollateralPct
  ) external {
    require(
      selfMintingDerivatives.length > 0,
      'No self-minting derivatives passed'
    );
    require(
      selfMintingDerivatives.length == overcollateralPct.length,
      'Number of derivatives and overcollaterals must be the same'
    );

    for (uint256 j; j < selfMintingDerivatives.length; j++) {
      _setCollateralRequirement(
        selfMintingDerivatives[j],
        overcollateralPct[j]
      );
    }
  }

  function setCapMintAmount(
    address[] calldata selfMintingDerivatives,
    uint256[] calldata capMintAmounts
  ) external {
    require(
      selfMintingDerivatives.length > 0,
      'No self-minting derivatives passed'
    );
    require(
      selfMintingDerivatives.length == capMintAmounts.length,
      'Number of derivatives and mint cap amounts must be the same'
    );
    for (uint256 j; j < selfMintingDerivatives.length; j++) {
      _setCapMintAmount(selfMintingDerivatives[j], capMintAmounts[j]);
    }
  }

  function setFeePercentage(
    address[] calldata selfMintingDerivatives,
    uint256[] calldata feePercentages
  ) external {
    uint256 selfMintingDerCount = selfMintingDerivatives.length;
    require(selfMintingDerCount > 0, 'No self-minting derivatives passed');
    require(
      selfMintingDerCount == feePercentages.length,
      'Number of derivatives and  fee percentages must be the same'
    );
    for (uint256 j; j < selfMintingDerCount; j++) {
      _setFeePercentage(selfMintingDerivatives[j], feePercentages[j]);
    }
  }

  function setFeeRecipients(
    address[] calldata selfMintingDerivatives,
    address[][] calldata feeRecipients,
    uint32[][] calldata feeProportions
  ) external {
    require(
      selfMintingDerivatives.length == feeRecipients.length,
      'Mismatch between derivatives to update and fee recipients'
    );
    require(
      selfMintingDerivatives.length == feeProportions.length,
      'Mismatch between derivatives to update and fee proportions'
    );

    // update each derivative fee parameters
    for (uint256 j; j < selfMintingDerivatives.length; j++) {
      _setFeeRecipients(
        selfMintingDerivatives[j],
        feeRecipients[j],
        feeProportions[j]
      );
    }
  }

  function setLiquidationRewardPercentage(
    address[] calldata selfMintingDerivatives,
    FixedPoint.Unsigned[] calldata _liquidationRewards
  ) external {
    for (uint256 j = 0; j < selfMintingDerivatives.length; j++) {
      require(
        _liquidationRewards[j].isGreaterThan(0) &&
          _liquidationRewards[j].isLessThanOrEqual(
            FixedPoint.fromUnscaledUint(1)
          ),
        'Liquidation reward must be between 0 and 1 (100%)'
      );

      liquidationReward[selfMintingDerivatives[j]] = _liquidationRewards[j];
    }
  }

  function getCollateralRequirement(address selfMintingDerivative)
    external
    view
    returns (uint256)
  {
    return overCollateralizationPercentage[selfMintingDerivative].rawValue;
  }

  function getLiquidationRewardPercentage(address selfMintingDerivative)
    external
    view
    returns (uint256)
  {
    return liquidationReward[selfMintingDerivative].rawValue;
  }

  function getFeeInfo(address selfMintingDerivative)
    external
    view
    returns (ICreditLineStorage.Fee memory)
  {
    return fee[selfMintingDerivative];
  }

  function getCapMintAmount(address selfMintingDerivative)
    external
    view
    returns (uint256 capMintAmount)
  {
    return capMint[selfMintingDerivative];
  }

  //----------------------------------------
  // Internal functions
  //----------------------------------------

  function _setCollateralRequirement(
    address selfMintingDerivative,
    uint256 percentage
  ) internal {
    overCollateralizationPercentage[selfMintingDerivative] = FixedPoint
      .Unsigned(percentage);
  }

  function _setFeeRecipients(
    address selfMintingDerivative,
    address[] calldata feeRecipients,
    uint32[] calldata feeProportions
  ) internal {
    uint256 totalActualFeeProportions = 0;

    // Store the sum of all proportions
    for (uint256 i = 0; i < feeProportions.length; i++) {
      totalActualFeeProportions += feeProportions[i];

      fee[selfMintingDerivative].feeRecipients = feeRecipients;
      fee[selfMintingDerivative].feeProportions = feeProportions;
      fee[selfMintingDerivative]
        .totalFeeProportions = totalActualFeeProportions;
    }
  }

  function _setFeePercentage(
    address selfMintingDerivative,
    uint256 feePercentage
  ) internal {
    require(
      fee[selfMintingDerivative].feePercentage.rawValue != feePercentage,
      ' fee percentage is the same'
    );
    fee[selfMintingDerivative].feePercentage = FixedPoint.Unsigned(
      feePercentage
    );
  }

  function _setCapMintAmount(
    address selfMintingDerivative,
    uint256 capMintAmount
  ) internal {
    require(
      capMint[selfMintingDerivative] != capMintAmount,
      'Cap mint amount is the same'
    );
    capMint[selfMintingDerivative] = capMintAmount;
  }
}
