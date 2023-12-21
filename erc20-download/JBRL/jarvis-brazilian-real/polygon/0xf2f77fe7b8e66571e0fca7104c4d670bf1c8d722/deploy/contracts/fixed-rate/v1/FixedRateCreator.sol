// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IStandardERC20} from '../../base/interfaces/IStandardERC20.sol';
import {
  IMintableBurnableTokenFactory
} from '../../tokens/factories/interfaces/IMintableBurnableTokenFactory.sol';
import {ISynthereumFinder} from '../../core/interfaces/IFinder.sol';
import {
  IMintableBurnableERC20
} from '../../tokens/interfaces/IMintableBurnableERC20.sol';
import {
  BaseControlledMintableBurnableERC20
} from '../../tokens/BaseControlledMintableBurnableERC20.sol';
import {SynthereumInterfaces} from '../../core/Constants.sol';
import {SynthereumFixedRateWrapper} from './FixedRateWrapper.sol';
import {ISynthereumFixedRateWrapper} from './interfaces/IFixedRateWrapper.sol';

contract SynthereumFixedRateCreator {
  struct Params {
    IStandardERC20 collateralToken;
    string syntheticName;
    string syntheticSymbol;
    address syntheticToken;
    ISynthereumFixedRateWrapper.Roles roles;
    uint8 version;
    uint256 rate;
  }

  // Address of Synthereum Finder
  ISynthereumFinder public immutable synthereumFinder;

  //----------------------------------------
  // Constructor
  //----------------------------------------

  /**
   * @notice Constructs the FixedRateWrapper contract.
   * @param _synthereumFinder Synthereum Finder address used to discover other contracts
   */
  constructor(address _synthereumFinder) {
    synthereumFinder = ISynthereumFinder(_synthereumFinder);
  }

  //----------------------------------------
  // Public functions
  //----------------------------------------

  /**
   * @notice Creates an instance of the fixed rate
   * @param _params is a `ConstructorParams` object from FixedRateWrapper.
   * @return fixedRate Address of the deployed fixedRate contract.
   */
  function createFixedRate(Params calldata _params)
    public
    virtual
    returns (SynthereumFixedRateWrapper fixedRate)
  {
    require(bytes(_params.syntheticName).length != 0, 'Missing synthetic name');
    require(
      bytes(_params.syntheticSymbol).length != 0,
      'Missing synthetic symbol'
    );

    if (_params.syntheticToken == address(0)) {
      IMintableBurnableTokenFactory tokenFactory =
        IMintableBurnableTokenFactory(
          ISynthereumFinder(synthereumFinder).getImplementationAddress(
            SynthereumInterfaces.TokenFactory
          )
        );
      BaseControlledMintableBurnableERC20 tokenCurrency =
        tokenFactory.createToken(
          _params.syntheticName,
          _params.syntheticSymbol,
          18
        );
      fixedRate = new SynthereumFixedRateWrapper(
        _convertParams(_params, tokenCurrency)
      );
      // Give permissions to new pool contract and then hand over ownership.
      tokenCurrency.addMinter(address(fixedRate));
      tokenCurrency.addBurner(address(fixedRate));
      tokenCurrency.addAdmin(
        synthereumFinder.getImplementationAddress(SynthereumInterfaces.Manager)
      );
      tokenCurrency.renounceAdmin();
    } else {
      BaseControlledMintableBurnableERC20 tokenCurrency =
        BaseControlledMintableBurnableERC20(_params.syntheticToken);
      require(
        keccak256(abi.encodePacked(tokenCurrency.name())) ==
          keccak256(abi.encodePacked(_params.syntheticName)),
        'Wrong synthetic token name'
      );
      require(
        keccak256(abi.encodePacked(tokenCurrency.symbol())) ==
          keccak256(abi.encodePacked(_params.syntheticSymbol)),
        'Wrong synthetic token symbol'
      );
      fixedRate = new SynthereumFixedRateWrapper(
        _convertParams(_params, tokenCurrency)
      );
    }
    return fixedRate;
  }

  // Converts createFixedRate params to constructor params.
  function _convertParams(
    Params memory _params,
    BaseControlledMintableBurnableERC20 _tokenCurrency
  )
    internal
    view
    returns (
      SynthereumFixedRateWrapper.ConstructorParams memory constructorParams
    )
  {
    require(_params.roles.admin != address(0), 'Admin cannot be 0x00');
    constructorParams.finder = synthereumFinder;
    constructorParams.version = _params.version;
    constructorParams.pegCollateralToken = _params.collateralToken;
    constructorParams.fixedRateToken = IMintableBurnableERC20(
      address(_tokenCurrency)
    );
    constructorParams.roles = _params.roles;
    constructorParams.rate = _params.rate;
  }
}
