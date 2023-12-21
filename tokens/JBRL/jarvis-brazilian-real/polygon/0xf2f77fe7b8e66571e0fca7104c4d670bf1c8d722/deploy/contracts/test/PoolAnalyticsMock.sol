// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ISynthereumFinder} from '../core/interfaces/IFinder.sol';
import {
  ILendingManager
} from '../lending-module/interfaces/ILendingManager.sol';
import {
  ILendingStorageManager
} from '../lending-module/interfaces/ILendingStorageManager.sol';
import {
  ISynthereumMultiLpLiquidityPool
} from '../synthereum-pool/v6/interfaces/IMultiLpLiquidityPool.sol';
import {SynthereumInterfaces} from '../core/Constants.sol';
import {PreciseUnitMath} from '../base/utils/PreciseUnitMath.sol';
import {
  SafeERC20
} from '../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract PoolAnalyticsMock {
  using PreciseUnitMath for uint256;
  using SafeERC20 for IERC20;

  ISynthereumFinder public immutable finder;

  uint256 public preCapacity;

  uint256 public postCapacity;

  uint256 public collAmount;

  uint256 public tokensMinted;

  uint256 public poolInterest;

  struct TotalCollateral {
    uint256 usersCollateral;
    uint256 lpsCollateral;
    uint256 totalCollateral;
  }

  struct Interest {
    uint256 poolInterest;
    uint256 commissionInterest;
    uint256 buybackInterest;
  }

  struct Amounts {
    uint256 totalSynthTokens;
    uint256 totCapacity;
    uint256 poolBearingBalance;
    uint256 poolCollBalance;
    uint256 expectedBearing;
  }

  constructor(address _finder) {
    finder = ISynthereumFinder(_finder);
  }

  function getAllPoolData(address _pool, address[] calldata _lps)
    external
    view
    returns (
      ILendingStorageManager.PoolStorage memory poolData,
      TotalCollateral memory totColl,
      Amounts memory amounts,
      ISynthereumMultiLpLiquidityPool.LPInfo[] memory lpsInfo,
      Interest memory interest
    )
  {
    ILendingStorageManager storageManager =
      ILendingStorageManager(
        finder.getImplementationAddress(
          SynthereumInterfaces.LendingStorageManager
        )
      );
    ILendingManager lendingManager =
      ILendingManager(
        finder.getImplementationAddress(SynthereumInterfaces.LendingManager)
      );
    poolData = storageManager.getPoolStorage(_pool);
    ISynthereumMultiLpLiquidityPool poolContract =
      ISynthereumMultiLpLiquidityPool(_pool);
    (
      totColl.usersCollateral,
      totColl.lpsCollateral,
      totColl.totalCollateral
    ) = poolContract.totalCollateralAmount();
    amounts.totalSynthTokens = poolContract.totalSyntheticTokens();
    amounts.totCapacity = poolContract.maxTokensCapacity();
    amounts.poolBearingBalance = IERC20(poolData.interestBearingToken)
      .balanceOf(_pool);
    amounts.poolCollBalance = IERC20(poolData.collateral).balanceOf(_pool);
    (
      interest.poolInterest,
      interest.commissionInterest,
      interest.buybackInterest,

    ) = lendingManager.getAccumulatedInterest(_pool);
    (amounts.expectedBearing, ) = lendingManager.collateralToInterestToken(
      _pool,
      poolData.collateralDeposited +
        poolData.unclaimedDaoJRT +
        poolData.unclaimedDaoCommission +
        interest.poolInterest +
        interest.commissionInterest +
        interest.buybackInterest
    );
    lpsInfo = new ISynthereumMultiLpLiquidityPool.LPInfo[](_lps.length);
    for (uint256 j = 0; j < _lps.length; j++) {
      lpsInfo[j] = poolContract.positionLPInfo(_lps[j]);
    }
  }

  function depositCapacity(
    address _pool,
    uint256 _price,
    bool _moreCollateral,
    uint256 _exceedingAmount
  ) external {
    ISynthereumMultiLpLiquidityPool poolContract =
      ISynthereumMultiLpLiquidityPool(_pool);
    uint256 maxCapacity = poolContract.maxTokensCapacity();
    IERC20 collateralContract = poolContract.collateralToken();
    uint8 decimals = poolContract.collateralTokenDecimals();
    uint256 collateralAmount =
      _moreCollateral
        ? maxCapacity.mul(_price) / (10**(18 - decimals)) + _exceedingAmount
        : maxCapacity.mul(_price) / (10**(18 - decimals)) - _exceedingAmount;
    preCapacity = maxCapacity;
    collAmount = collateralAmount;
    collateralContract.safeTransferFrom(
      msg.sender,
      address(this),
      collateralAmount
    );
    collateralContract.safeApprove(_pool, collateralAmount);
    (tokensMinted, ) = poolContract.mint(
      ISynthereumMultiLpLiquidityPool.MintParams(
        0,
        collateralAmount,
        PreciseUnitMath.maxUint256(),
        msg.sender
      )
    );
    postCapacity = poolContract.maxTokensCapacity();
  }

  function updatePositions(address _pool) external {
    ISynthereumMultiLpLiquidityPool poolContract =
      ISynthereumMultiLpLiquidityPool(_pool);
    ILendingManager lendingManager =
      ILendingManager(
        finder.getImplementationAddress(SynthereumInterfaces.LendingManager)
      );
    (poolInterest, , , ) = lendingManager.getAccumulatedInterest(_pool);
    poolContract.updatePositions();
  }
}
