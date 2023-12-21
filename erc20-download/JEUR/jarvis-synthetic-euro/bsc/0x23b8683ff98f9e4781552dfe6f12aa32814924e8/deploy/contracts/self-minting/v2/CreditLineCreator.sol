// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {IStandardERC20} from '../../base/interfaces/IStandardERC20.sol';
import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {ICreditLineController} from './interfaces/ICreditLineController.sol';
import {ICreditLineStorage} from './interfaces/ICreditLineStorage.sol';
import {
  IMintableBurnableERC20
} from '../../tokens/interfaces/IMintableBurnableERC20.sol';
import {
  BaseControlledMintableBurnableERC20
} from '../../tokens/interfaces/BaseControlledMintableBurnableERC20.sol';
import {SynthereumInterfaces} from '../../core/Constants.sol';
import {
  FixedPoint
} from '../../../@uma/core/contracts/common/implementation/FixedPoint.sol';
import {CreditLineLib} from './CreditLineLib.sol';
import {CreditLine} from './CreditLine.sol';

/**
 * @title Self-Minting Contract creator.
 * @notice Factory contract to create new self-minting derivative
 */
contract CreditLineCreator {
  using FixedPoint for FixedPoint.Unsigned;

  struct Params {
    IStandardERC20 collateralToken;
    bytes32 priceFeedIdentifier;
    string syntheticName;
    string syntheticSymbol;
    address syntheticToken;
    ICreditLineStorage.Fee fee;
    uint256 liquidationPercentage;
    uint256 capMintAmount;
    uint256 collateralRequirement;
    FixedPoint.Unsigned minSponsorTokens;
    address excessTokenBeneficiary;
    uint8 version;
  }

  // Address of Synthereum Finder
  ISynthereumFinder public immutable synthereumFinder;

  //----------------------------------------
  // Events
  //----------------------------------------
  event CreatedSelfMintingDerivative(
    address indexed selfMintingAddress,
    uint8 indexed version,
    address indexed deployerAddress
  );

  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Constructs the Perpetual contract.
   * @param _synthereumFinder Synthereum Finder address used to discover other contracts
   */
  constructor(address _synthereumFinder) {
    synthereumFinder = ISynthereumFinder(_synthereumFinder);
  }

  //----------------------------------------
  // External functions
  //----------------------------------------

  /**
   * @notice Creates an instance of creditLine
   * @param params is a `ConstructorParams` object from creditLine.
   * @return creditLine address of the deployed contract.
   */
  function createSelfMintingDerivative(Params calldata params)
    public
    virtual
    returns (CreditLine creditLine)
  {
    // Create a new synthetic token using the params.
    require(bytes(params.syntheticName).length != 0, 'Missing synthetic name');
    require(
      bytes(params.syntheticSymbol).length != 0,
      'Missing synthetic symbol'
    );
    require(
      params.syntheticToken != address(0),
      'Synthetic token address cannot be 0x00'
    );

    BaseControlledMintableBurnableERC20 tokenCurrency =
      BaseControlledMintableBurnableERC20(params.syntheticToken);
    require(
      keccak256(abi.encodePacked(tokenCurrency.name())) ==
        keccak256(abi.encodePacked(params.syntheticName)),
      'Wrong synthetic token name'
    );
    require(
      keccak256(abi.encodePacked(tokenCurrency.symbol())) ==
        keccak256(abi.encodePacked(params.syntheticSymbol)),
      'Wrong synthetic token symbol'
    );

    creditLine = new CreditLine(_convertParams(params));

    _setControllerValues(
      address(creditLine),
      params.fee,
      params.liquidationPercentage,
      params.capMintAmount,
      params.collateralRequirement
    );

    emit CreatedSelfMintingDerivative(
      address(creditLine),
      params.version,
      msg.sender
    );
  }

  //----------------------------------------
  // Internal functions
  //----------------------------------------

  // Converts createPerpetual params to constructor params.
  function _convertParams(Params calldata params)
    internal
    view
    returns (CreditLine.PositionManagerParams memory constructorParams)
  {
    constructorParams.synthereumFinder = synthereumFinder;

    require(
      params.excessTokenBeneficiary != address(0),
      'Token Beneficiary cannot be 0x00'
    );

    constructorParams.syntheticToken = IMintableBurnableERC20(
      address(params.syntheticToken)
    );
    constructorParams.collateralToken = params.collateralToken;
    constructorParams.priceFeedIdentifier = params.priceFeedIdentifier;
    constructorParams.minSponsorTokens = params.minSponsorTokens;
    constructorParams.excessTokenBeneficiary = params.excessTokenBeneficiary;
    constructorParams.version = params.version;
  }

  /** @notice Sets the controller values for a self-minting derivative
   * @param derivative Address of the derivative to set controller values
   * @param feeStruct The fee config params
   * @param capMintAmount Cap on mint amount. How much synthetic tokens can be minted through a self-minting derivative.
   * This value is updatable
   */
  function _setControllerValues(
    address derivative,
    ICreditLineStorage.Fee memory feeStruct,
    uint256 liquidationRewardPercentage,
    uint256 capMintAmount,
    uint256 collateralRequirement
  ) internal {
    ICreditLineController creditLineController =
      ICreditLineController(
        synthereumFinder.getImplementationAddress(
          SynthereumInterfaces.CreditLineController
        )
      );

    // prepare function calls args
    address[] memory derivatives = new address[](1);
    derivatives[0] = derivative;

    uint256[] memory capMintAmounts = new uint256[](1);
    capMintAmounts[0] = capMintAmount;

    uint256[] memory collateralRequirements = new uint256[](1);
    collateralRequirements[0] = collateralRequirement;

    FixedPoint.Unsigned[] memory feePercentages = new FixedPoint.Unsigned[](1);
    feePercentages[0] = feeStruct.feePercentage;

    FixedPoint.Unsigned[] memory liqPercentages = new FixedPoint.Unsigned[](1);
    liqPercentages[0] = FixedPoint.Unsigned(liquidationRewardPercentage);

    address[][] memory feeRecipients = new address[][](1);
    feeRecipients[0] = feeStruct.feeRecipients;

    uint32[][] memory feeProportions = new uint32[][](1);
    feeProportions[0] = feeStruct.feeProportions;

    // set the derivative over collateralization percentage
    creditLineController.setCollateralRequirement(
      derivatives,
      collateralRequirements
    );

    // set the derivative fee configuration
    creditLineController.setFeePercentage(derivatives, feePercentages);
    creditLineController.setFeeRecipients(
      derivatives,
      feeRecipients,
      feeProportions
    );

    // set the derivative cap mint amount
    creditLineController.setCapMintAmount(derivatives, capMintAmounts);

    // set the derivative liquidation reward percentage
    creditLineController.setLiquidationRewardPercentage(
      derivatives,
      liqPercentages
    );
  }
}
