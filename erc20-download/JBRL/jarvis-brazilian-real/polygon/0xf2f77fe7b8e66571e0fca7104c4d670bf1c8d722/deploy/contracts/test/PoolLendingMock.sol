// SPDX-License-Identifier: AGPL-3.0-only

import {IERC20} from '../../@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  ILendingManager
} from '../lending-module/interfaces/ILendingManager.sol';
import {
  ILendingStorageManager
} from '../lending-module/interfaces/ILendingStorageManager.sol';
import {ISynthereumDeployment} from '../common/interfaces/IDeployment.sol';
import {ISynthereumFinder} from '../core/interfaces/IFinder.sol';
import {ExplicitERC20} from '../base/utils/ExplicitERC20.sol';
import {
  SafeERC20
} from '../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface ATokenMock is IERC20 {
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface AAVEMock {
  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256);
}

contract PoolLendingMock is ISynthereumDeployment {
  using SafeERC20 for IERC20;
  using ExplicitERC20 for IERC20;

  IERC20 collToken;
  IERC20 synthToken;
  ILendingManager proxy;
  ILendingStorageManager storageManager;

  constructor(
    address collateral,
    address synth,
    address lendingProxy,
    address storageMan
  ) {
    collToken = IERC20(collateral);
    synthToken = IERC20(synth);
    proxy = ILendingManager(lendingProxy);
    storageManager = ILendingStorageManager(storageMan);
  }

  function synthereumFinder() external pure returns (ISynthereumFinder finder) {
    return finder;
  }

  function version() external pure returns (uint8 contractVersion) {
    return 0;
  }

  function collateralToken() external view returns (IERC20) {
    return collToken;
  }

  function syntheticToken() external view returns (IERC20 syntheticCurrency) {
    return synthToken;
  }

  function syntheticTokenSymbol() external pure returns (string memory symbol) {
    return 'test';
  }

  function deposit(uint256 amount, address token)
    external
    returns (ILendingManager.ReturnValues memory)
  {
    IERC20(token).safeTransferFrom(msg.sender, address(proxy), amount);
    return proxy.deposit(amount);
  }

  function depositShouldRevert(uint256 amount)
    external
    returns (ILendingManager.ReturnValues memory)
  {
    return proxy.deposit(amount);
  }

  function updateAccumulatedInterest()
    external
    returns (ILendingManager.ReturnValues memory)
  {
    return proxy.updateAccumulatedInterest();
  }

  function withdraw(
    uint256 amount,
    address recipient,
    address token
  ) external returns (ILendingManager.ReturnValues memory) {
    IERC20(token).transfer(address(proxy), amount);
    return proxy.withdraw(amount, recipient);
  }

  function withdrawShouldRevert(uint256 amount, address recipient)
    external
    returns (ILendingManager.ReturnValues memory)
  {
    return proxy.withdraw(amount, recipient);
  }

  function transferToLendingManager(uint256 bearingAmount)
    external
    returns (uint256)
  {
    address interestAddr =
      storageManager.getInterestBearingToken(address(this));
    (uint256 amountTransferred, ) =
      IERC20(interestAddr).explicitSafeTransfer(address(proxy), bearingAmount);
    return amountTransferred;
  }

  function migrateLendingModule(
    address interestToken,
    string memory newLendingModuleID,
    address newInterestBearingToken,
    uint256 interestTokenAmount
  ) external returns (ILendingManager.MigrateReturnValues memory) {
    IERC20(interestToken).transfer(address(proxy), interestTokenAmount);
    return
      proxy.migrateLendingModule(
        newLendingModuleID,
        newInterestBearingToken,
        interestTokenAmount
      );
  }

  function migrateTotalFunds(address _recipient)
    external
    returns (uint256 migrationAmount)
  {
    IERC20 bearingToken =
      IERC20(storageManager.getInterestBearingToken(address(this)));
    migrationAmount = bearingToken.balanceOf(address(this));
    bearingToken.safeTransfer(_recipient, migrationAmount);
  }
}
