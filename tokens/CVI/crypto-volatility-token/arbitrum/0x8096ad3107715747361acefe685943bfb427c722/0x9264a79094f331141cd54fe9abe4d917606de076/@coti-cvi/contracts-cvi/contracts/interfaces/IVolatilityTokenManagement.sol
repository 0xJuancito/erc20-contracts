// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./IPlatform.sol";
import "./IFeesCollector.sol";
import "./IFeesCalculator.sol";
import "./ICVIOracle.sol";
import "./IThetaVault.sol";

interface IVolatilityTokenManagement {

    event MinterSet(address minter);
    event PlatformSet(address newPlatform, address newToken, address swapRouter);
    event FeesCalculatorSet(address newFeesCalculator);
    event FeesCollectorSet(address newCollector);
    event CVIOracleSet(address newCVIOracle);
    event DeviationParametersSet(uint16 newDeviationPercentagePerSingleRebaseLag, uint16 newMinDeviationPercentage, uint16 newMaxDeviationPercentage);
    event CappedRebaseSet(bool newCappedRebase);
    event ThetaVaultSet(address newThetaVault);
    event PositionManagerSet(address newPositionManagerAddress);
    event FulfillerSet(address newFulfiller);
    event PostLiquidationMaxMintAmountSet(uint256 newPostLiquidationMaxMintAmount);

    function rebaseCVI() external;

    function setMinter(address minter) external;
    function setPlatform(IPlatform newPlatform, IERC20Upgradeable newToken, ISwapRouter swapRouter) external;
    function setFeesCalculator(IFeesCalculator newFeesCalculator) external;
    function setFeesCollector(IFeesCollector newCollector) external;
    function setCVIOracle(ICVIOracle newCVIOracle) external;
    function setDeviationParameters(uint16 newDeviationPercentagePerSingleRebaseLag, uint16 newMinDeviationPercentage, uint16 newMaxDeviationPercentage) external;
    function setCappedRebase(bool newCappedRebase) external;
    function setThetaVault(IThetaVault newThetaVault) external;
    function setPositionManager(address newPositionManagerAddress) external;

    function setFulfiller(address newFulfiller) external;

    function setPostLiquidationMaxMintAmount(uint256 newPostLiquidationMaxMintAmount) external;
}
