// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IERC20} from '../../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  ILendingModule
} from '../../lending-module/interfaces/ILendingModule.sol';
import {
  ILendingStorageManager
} from '../../lending-module/interfaces/ILendingStorageManager.sol';
import {
  SafeERC20
} from '../../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {PreciseUnitMath} from '../../base/utils/PreciseUnitMath.sol';
import {
  SynthereumPoolMigrationFrom
} from '../../synthereum-pool/common/migration/PoolMigrationFrom.sol';
import {LendingTestnetERC20} from './LendingTestnetERC20.sol';

contract LendingModulelMock is ILendingModule {
  using SafeERC20 for IERC20;
  using PreciseUnitMath for uint256;

  function deposit(
    ILendingStorageManager.PoolStorage calldata poolData,
    bytes memory lendingArgs,
    uint256 amount
  )
    external
    override
    returns (
      uint256 totalInterest,
      uint256 tokensOut,
      uint256 tokensTransferred
    )
  {
    IERC20 collateral = IERC20(poolData.collateral);
    require(collateral.balanceOf(address(this)) >= amount, 'Wrong balance');

    (uint256 exceedPrgDep, , bool isBonus) =
      abi.decode(lendingArgs, (uint256, uint256, bool));

    uint256 netDeposit =
      isBonus
        ? amount + amount.mul(exceedPrgDep)
        : amount - amount.mul(exceedPrgDep);

    address interestToken = poolData.interestBearingToken;
    collateral.safeIncreaseAllowance(interestToken, amount);
    LendingTestnetERC20(interestToken).deposit(msg.sender, amount, netDeposit);

    tokensOut = netDeposit;
    tokensTransferred = netDeposit;
  }

  function withdraw(
    ILendingStorageManager.PoolStorage calldata poolData,
    address pool,
    bytes memory lendingArgs,
    uint256 bearingTokensAmount,
    address recipient
  )
    external
    override
    returns (
      uint256 totalInterest,
      uint256 tokensOut,
      uint256 tokensTransferred
    )
  {
    (, uint256 exceedPrgWith, bool isBonus) =
      abi.decode(lendingArgs, (uint256, uint256, bool));

    uint256 netWithdrawal =
      isBonus
        ? bearingTokensAmount - bearingTokensAmount.mul(exceedPrgWith)
        : bearingTokensAmount + bearingTokensAmount.mul(exceedPrgWith);

    LendingTestnetERC20(poolData.interestBearingToken).withdraw(
      recipient,
      bearingTokensAmount,
      netWithdrawal
    );

    tokensOut = bearingTokensAmount;
    tokensTransferred = netWithdrawal;
  }

  function totalTransfer(
    address oldPool,
    address newPool,
    address collateral,
    address interestToken,
    bytes memory extraArgs
  )
    external
    returns (uint256 prevTotalCollateral, uint256 actualTotalCollateral)
  {
    prevTotalCollateral = SynthereumPoolMigrationFrom(oldPool)
      .migrateTotalFunds(newPool);
    actualTotalCollateral = IERC20(interestToken).balanceOf(newPool);
  }

  function getAccumulatedInterest(
    address poolAddress,
    ILendingStorageManager.PoolStorage calldata poolData,
    bytes memory extraArgs
  ) external view override returns (uint256 totalInterest) {}

  function getInterestBearingToken(address collateral, bytes memory args)
    external
    view
    override
    returns (address token)
  {
    revert('No bearing token to be calculated');
  }

  function collateralToInterestToken(
    uint256 collateralAmount,
    address collateral,
    address interestToken,
    bytes memory extraArgs
  ) external pure override returns (uint256 interestTokenAmount) {
    interestTokenAmount = collateralAmount;
  }

  function interestTokenToCollateral(
    uint256 interestTokenAmount,
    address collateral,
    address interestToken,
    bytes memory extraArgs
  ) external pure override returns (uint256 collateralAmount) {
    collateralAmount = interestTokenAmount;
  }
}
