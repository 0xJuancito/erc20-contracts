// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Governable, OperableKeepable} from "../../common/OperableKeepable.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IJonesBorrowableVault} from "../../interfaces/IJonesBorrowableVault.sol";
import {IJonesUsdVault} from "../../interfaces/IJonesUsdVault.sol";
import {IJonesGlpRewardDistributor} from "../../interfaces/IJonesGlpRewardDistributor.sol";
import {IAggregatorV3} from "../../interfaces/IAggregatorV3.sol";
import {IGmxRewardRouter} from "../../interfaces/IGmxRewardRouter.sol";
import {IJonesGlpLeverageStrategy} from "../../interfaces/IJonesGlpLeverageStrategy.sol";
import {IGlpManager} from "../../../src/interfaces/IGlpManager.sol";
import {IGMXVault} from "../../../src/interfaces/IGMXVault.sol";
import {IRewardTracker} from "../../../src/interfaces/IRewardTracker.sol";

contract JonesGlpLeverageStrategy is IJonesGlpLeverageStrategy, OperableKeepable, ReentrancyGuard {
    using Math for uint256;

    struct LeverageConfig {
        uint256 target;
        uint256 min;
        uint256 max;
    }

    IGmxRewardRouter constant routerV1 = IGmxRewardRouter(0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);
    IGmxRewardRouter constant routerV2 = IGmxRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
    IGlpManager constant glpManager = IGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
    address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant PRECISION = 1e30;
    uint256 public constant BASIS_POINTS = 1e12;
    uint256 public constant GMX_BASIS = 1e4;
    uint256 public constant USDC_DECIMALS = 1e6;
    uint256 public constant GLP_DECIMALS = 1e18;

    IERC20 public stable;
    IERC20 public glp;

    IJonesBorrowableVault stableVault;
    IJonesBorrowableVault glpVault;

    IJonesGlpRewardDistributor distributor;

    uint256 public stableDebt;

    LeverageConfig public leverageConfig;

    constructor(
        IJonesBorrowableVault _stableVault,
        IJonesBorrowableVault _glpVault,
        IJonesGlpRewardDistributor _distributor,
        LeverageConfig memory _leverageConfig,
        address _glp,
        address _stable
    ) Governable(msg.sender) ReentrancyGuard() {
        stableVault = _stableVault;
        glpVault = _glpVault;
        distributor = _distributor;

        stable = IERC20(_stable);
        glp = IERC20(_glp);

        _setLeverageConfig(_leverageConfig);
    }

    // ============================= Operator functions ================================ //

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function onGlpDeposit(uint256 _amount) external nonReentrant onlyOperator {
        _borrowGlp(_amount);
        if (leverage() < getTargetLeverage()) {
            _leverage(_amount);
        }
        _rebalance(getUnderlyingGlp());
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function onGlpRedeem(uint256 _amount) external nonReentrant onlyOperator returns (uint256) {
        if (_amount > getUnderlyingGlp()) {
            revert NotEnoughUnderlyingGlp();
        }

        uint256 glpRedeemRetention = glpRedeemRetention(_amount);
        uint256 assetsToRedeem = _amount - glpRedeemRetention;

        glp.transfer(msg.sender, assetsToRedeem);

        uint256 underlying = getUnderlyingGlp();
        uint256 leverageAmount = glp.balanceOf(address(this)) - underlying;
        uint256 protocolExcess = ((underlying * (leverageConfig.target - BASIS_POINTS)) / BASIS_POINTS);
        uint256 excessGlp;
        if (leverageAmount < protocolExcess) {
            excessGlp = leverageAmount;
        } else {
            excessGlp = ((_amount * (leverageConfig.target - BASIS_POINTS)) / BASIS_POINTS); // 18 Decimals
        }

        if (leverageAmount >= excessGlp && leverage() > getTargetLeverage()) {
            _deleverage(excessGlp);
        }

        underlying = getUnderlyingGlp();
        if (underlying > 0) {
            _rebalance(underlying);
        }

        emit Deleverage(excessGlp, assetsToRedeem);

        return assetsToRedeem;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function onStableDeposit() external nonReentrant onlyOperator {
        _rebalance(getUnderlyingGlp());
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function onStableRedeem(uint256 _amount, uint256 _amountAfterRetention) external onlyOperator returns (uint256) {
        (uint256 glpAmount,) = _getRequiredGlpAmount(_amountAfterRetention + 2);

        routerV2.unstakeAndRedeemGlp(address(stable), glpAmount, _amountAfterRetention, address(this));

        stable.transfer(msg.sender, _amountAfterRetention);

        stableDebt = stableDebt - _amount;

        return _amountAfterRetention;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function claimGlpRewards() external nonReentrant onlyOperatorOrKeeper {
        routerV1.handleRewards(false, false, true, true, true, true, false);

        uint256 rewards = IERC20(weth).balanceOf(address(this));

        uint256 currentLeverage = leverage();

        IERC20(weth).approve(address(distributor), rewards);
        distributor.splitRewards(rewards, currentLeverage, utilization());

        // Information needed to calculate rewards per Vault
        emit ClaimGlpRewards(
            tx.origin,
            msg.sender,
            rewards,
            block.timestamp,
            currentLeverage,
            glp.balanceOf(address(this)),
            getUnderlyingGlp(),
            glpVault.totalSupply(),
            stableDebt,
            stableVault.totalSupply()
            );
    }

    // ============================= Public functions ================================ //

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function utilization() public view returns (uint256) {
        uint256 borrowed = stableDebt;
        uint256 available = stable.balanceOf(address(stableVault));
        uint256 total = borrowed + available;

        if (total == 0) {
            return 0;
        }

        return (borrowed * BASIS_POINTS) / total;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function leverage() public view returns (uint256) {
        uint256 glpTvl = getUnderlyingGlp(); // 18 Decimals

        if (glpTvl == 0) {
            return 0;
        }

        if (stableDebt == 0) {
            return 1 * BASIS_POINTS;
        }

        return ((glp.balanceOf(address(this)) * BASIS_POINTS) / glpTvl); // 12 Decimals;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getUnderlyingGlp() public view returns (uint256) {
        uint256 currentBalance = glp.balanceOf(address(this));

        if (currentBalance == 0) {
            return 0;
        }

        if (stableDebt > 0) {
            (uint256 glpAmount,) = _getRequiredGlpAmount(stableDebt + 2);
            return currentBalance > glpAmount ? currentBalance - glpAmount : 0;
        } else {
            return currentBalance;
        }
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getStableGlpValue(uint256 _glpAmount) public view returns (uint256) {
        (uint256 _value,) = _sellGlpStableSimulation(_glpAmount);
        return _value;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function buyGlpStableSimulation(uint256 _stableAmount) public view returns (uint256) {
        return _buyGlpStableSimulation(_stableAmount);
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getRequiredStableAmount(uint256 _glpAmount) external view returns (uint256) {
        (uint256 stableAmount,) = _getRequiredStableAmount(_glpAmount);
        return stableAmount;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getRequiredGlpAmount(uint256 _stableAmount) external view returns (uint256) {
        (uint256 glpAmount,) = _getRequiredGlpAmount(_stableAmount);
        return glpAmount;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getRedeemStableGMXIncentive(uint256 _stableAmount) external view returns (uint256) {
        (, uint256 gmxRetention) = _getRequiredGlpAmount(_stableAmount);
        return gmxRetention;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function glpMintIncentive(uint256 _glpAmount) public view returns (uint256) {
        return _glpMintIncentive(_glpAmount);
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function glpRedeemRetention(uint256 _glpAmount) public view returns (uint256) {
        return _glpRedeemRetention(_glpAmount);
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getMaxLeverage() public view returns (uint256) {
        return leverageConfig.max;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getMinLeverage() public view returns (uint256) {
        return leverageConfig.min;
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getGMXCapDifference() public view returns (uint256) {
        return _getGMXCapDifference();
    }

    /**
     * @inheritdoc IJonesGlpLeverageStrategy
     */
    function getTargetLeverage() public view returns (uint256) {
        return leverageConfig.target;
    }

    // ============================= Governor functions ================================ //

    /**
     * @notice Set Leverage Configuration
     * @dev Precision is based on 1e12 as 1x leverage
     * @param _target Target leverage
     * @param _min Min Leverage
     * @param _max Max Leverage
     * @param rebalance_ If is true trigger a rebalance
     */
    function setLeverageConfig(uint256 _target, uint256 _min, uint256 _max, bool rebalance_) public onlyGovernor {
        _setLeverageConfig(LeverageConfig(_target, _min, _max));
        emit SetLeverageConfig(_target, _min, _max);
        if (rebalance_) {
            _rebalance(getUnderlyingGlp());
        }
    }

    /**
     * @notice Set new glp address
     * @param _glp GLP address
     */
    function setGlpAddress(address _glp) external onlyGovernor {
        address oldGlp = address(glp);
        glp = IERC20(_glp);
        emit UpdateGlpAddress(oldGlp, _glp);
    }

    /**
     * @notice Set new stable address
     * @param _stable Stable addresss
     */
    function setStableAddress(address _stable) external onlyGovernor {
        address oldStable = address(stable);
        stable = IERC20(_stable);
        emit UpdateStableAddress(oldStable, _stable);
    }

    /**
     * @notice Emergency withdraw GLP in this contract
     * @param _to address to send the funds
     */
    function emergencyWithdraw(address _to) external onlyGovernor {
        uint256 currentBalance = glp.balanceOf(address(this));

        if (currentBalance == 0) {
            return;
        }

        glp.transfer(_to, currentBalance);

        emit EmergencyWithdraw(_to, currentBalance);
    }

    /**
     * @notice GMX function to signal transfer position
     * @param _to address to send the funds
     * @param _gmxRouter address of gmx router with the function
     */
    function transferAccount(address _to, address _gmxRouter) external onlyGovernor {
        if (_to == address(0)) {
            revert ZeroAddressError();
        }

        IGmxRewardRouter(_gmxRouter).signalTransfer(_to);
    }

    /**
     * @notice GMX function to accept transfer position
     * @param _sender address to receive the funds
     * @param _gmxRouter address of gmx router with the function
     */
    function acceptAccountTransfer(address _sender, address _gmxRouter) external onlyGovernor {
        IGmxRewardRouter gmxRouter = IGmxRewardRouter(_gmxRouter);

        gmxRouter.acceptTransfer(_sender);
    }

    // ============================= Keeper functions ================================ //

    /**
     * @notice Using by the bot to rebalance if is it needed
     */
    function rebalance() external onlyKeeper {
        _rebalance(getUnderlyingGlp());
    }

    /**
     * @notice Deleverage & pay stable debt
     */
    function unwind() external onlyGovernorOrKeeper {
        _setLeverageConfig(LeverageConfig(BASIS_POINTS + 1, BASIS_POINTS, BASIS_POINTS + 2));
        _liquidate();
    }

    /**
     * @notice Using by the bot to leverage Up if is needed
     */
    function leverageUp(uint256 _stableAmount) external onlyKeeper {
        uint256 availableForBorrowing = stable.balanceOf(address(stableVault));

        if (availableForBorrowing == 0) {
            return;
        }

        uint256 oldLeverage = leverage();

        _stableAmount = _adjustToGMXCap(_stableAmount);

        if (_stableAmount < 1e4) {
            return;
        }

        if (availableForBorrowing < _stableAmount) {
            _stableAmount = availableForBorrowing;
        }

        uint256 stableToBorrow = _stableAmount - stable.balanceOf(address(this));

        stableVault.borrow(stableToBorrow);
        emit BorrowStable(stableToBorrow);

        stableDebt = stableDebt + stableToBorrow;

        address stableAsset = address(stable);
        IERC20(stableAsset).approve(routerV2.glpManager(), _stableAmount);
        routerV2.mintAndStakeGlp(stableAsset, _stableAmount, 0, 0);

        uint256 newLeverage = leverage();

        if (newLeverage > getMaxLeverage()) {
            revert OverLeveraged();
        }

        emit LeverageUp(stableDebt, oldLeverage, newLeverage);
    }

    /**
     * @notice Using by the bot to leverage Down if is needed
     */
    function leverageDown(uint256 _glpAmount) external onlyKeeper {
        uint256 oldLeverage = leverage();

        uint256 stablesReceived = routerV2.unstakeAndRedeemGlp(address(stable), _glpAmount, 0, address(this));

        uint256 currentStableDebt = stableDebt;

        if (stablesReceived <= currentStableDebt) {
            _repayStable(stablesReceived);
        } else {
            _repayStable(currentStableDebt);
        }

        uint256 newLeverage = leverage();

        if (newLeverage < getMinLeverage()) {
            revert UnderLeveraged();
        }

        emit LeverageDown(stableDebt, oldLeverage, newLeverage);
    }

    // ============================= Private functions ================================ //

    function _rebalance(uint256 _glpDebt) private {
        uint256 currentLeverage = leverage();

        LeverageConfig memory currentLeverageConfig = leverageConfig;

        if (currentLeverage < currentLeverageConfig.min) {
            uint256 missingGlp = (_glpDebt * (currentLeverageConfig.target - currentLeverage)) / BASIS_POINTS; // 18 Decimals

            (uint256 stableToDeposit,) = _getRequiredStableAmount(missingGlp); // 6 Decimals

            stableToDeposit = _adjustToGMXCap(stableToDeposit);

            if (stableToDeposit < 1e4) {
                return;
            }

            uint256 availableForBorrowing = stable.balanceOf(address(stableVault));

            if (availableForBorrowing == 0) {
                return;
            }

            if (availableForBorrowing < stableToDeposit) {
                stableToDeposit = availableForBorrowing;
            }

            uint256 stableToBorrow = stableToDeposit - stable.balanceOf(address(this));

            stableVault.borrow(stableToBorrow);
            emit BorrowStable(stableToBorrow);

            stableDebt = stableDebt + stableToBorrow;

            address stableAsset = address(stable);
            IERC20(stableAsset).approve(routerV2.glpManager(), stableToDeposit);
            routerV2.mintAndStakeGlp(stableAsset, stableToDeposit, 0, 0);

            emit Rebalance(_glpDebt, currentLeverage, leverage(), tx.origin);

            return;
        }

        if (currentLeverage > currentLeverageConfig.max) {
            uint256 excessGlp = (_glpDebt * (currentLeverage - currentLeverageConfig.target)) / BASIS_POINTS;

            uint256 stablesReceived = routerV2.unstakeAndRedeemGlp(address(stable), excessGlp, 0, address(this));

            uint256 currentStableDebt = stableDebt;

            if (stablesReceived <= currentStableDebt) {
                _repayStable(stablesReceived);
            } else {
                _repayStable(currentStableDebt);
            }

            emit Rebalance(_glpDebt, currentLeverage, leverage(), tx.origin);

            return;
        }

        return;
    }

    function _liquidate() private {
        if (stableDebt == 0) {
            return;
        }

        uint256 glpBalance = glp.balanceOf(address(this));

        (uint256 glpAmount,) = _getRequiredGlpAmount(stableDebt + 2);

        if (glpAmount > glpBalance) {
            glpAmount = glpBalance;
        }

        uint256 stablesReceived = routerV2.unstakeAndRedeemGlp(address(stable), glpAmount, 0, address(this));

        uint256 currentStableDebt = stableDebt;

        if (stablesReceived <= currentStableDebt) {
            _repayStable(stablesReceived);
        } else {
            _repayStable(currentStableDebt);
        }

        emit Liquidate(stablesReceived);
    }

    function _borrowGlp(uint256 _amount) private returns (uint256) {
        glpVault.borrow(_amount);

        emit BorrowGlp(_amount);

        return _amount;
    }

    function _repayStable(uint256 _amount) internal returns (uint256) {
        stable.approve(address(stableVault), _amount);

        uint256 updatedAmount = stableDebt - stableVault.repay(_amount);

        stableDebt = updatedAmount;

        return updatedAmount;
    }

    function _setLeverageConfig(LeverageConfig memory _config) private {
        if (
            _config.min >= _config.max || _config.min >= _config.target || _config.max <= _config.target
                || _config.min < BASIS_POINTS
        ) {
            revert InvalidLeverageConfig();
        }

        leverageConfig = _config;
    }

    function _getRequiredGlpAmount(uint256 _stableAmount) private view returns (uint256, uint256) {
        // Working as expected, will get the amount of glp nedeed to get a few less stables than expected
        // If you have to get an amount greater or equal of _stableAmount, use _stableAmount + 2
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 usdcPrice = vault.getMaxPrice(usdc); // 30 decimals

        uint256 glpSupply = glp.totalSupply();

        uint256 glpPrice = manager.getAum(false).mulDiv(GLP_DECIMALS, glpSupply, Math.Rounding.Down); // 30 decimals

        uint256 usdgAmount = _stableAmount.mulDiv(usdcPrice, PRECISION, Math.Rounding.Down) * BASIS_POINTS; // 18 decimals

        uint256 glpAmount = _stableAmount.mulDiv(usdcPrice, glpPrice, Math.Rounding.Down) * BASIS_POINTS; // 18 decimals

        uint256 retentionBasisPoints =
            vault.getFeeBasisPoints(usdc, usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), false);

        uint256 glpRequired = (glpAmount * GMX_BASIS) / (GMX_BASIS - retentionBasisPoints);

        (uint256 theoreticalStables,) = _sellGlpStableSimulation(glpRequired);

        while (theoreticalStables < _stableAmount - 2) {
            retentionBasisPoints = retentionBasisPoints + 1;
            glpRequired = (glpAmount * GMX_BASIS) / (GMX_BASIS - retentionBasisPoints);
            (theoreticalStables,) = _sellGlpStableSimulation(glpRequired);
        }

        return (glpRequired, retentionBasisPoints);
    }

    function _getRequiredStableAmount(uint256 _glpAmount) private view returns (uint256, uint256) {
        // Working as expected, will get the amount of stables nedeed to get a few less glp than expected
        // If you have to get an amount greater or equal of _glpAmount, use _glpAmount + 2
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 usdcPrice = vault.getMinPrice(usdc); // 30 decimals

        uint256 glpPrice = manager.getAum(true).mulDiv(GLP_DECIMALS, glp.totalSupply(), Math.Rounding.Down); // 30 decimals

        uint256 stableAmount = _glpAmount.mulDiv(glpPrice, usdcPrice, Math.Rounding.Down); // 18 decimals

        uint256 usdgAmount = _glpAmount.mulDiv(glpPrice, PRECISION, Math.Rounding.Down); // 18 decimals

        uint256 retentionBasisPoints =
            vault.getFeeBasisPoints(usdc, usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), true);

        return ((stableAmount * GMX_BASIS / (GMX_BASIS - retentionBasisPoints)) / BASIS_POINTS, retentionBasisPoints); // 18 decimals
    }

    function _leverage(uint256 _glpAmount) private {
        uint256 missingGlp = ((_glpAmount * (leverageConfig.target - BASIS_POINTS)) / BASIS_POINTS); // 18 Decimals

        (uint256 stableToDeposit,) = _getRequiredStableAmount(missingGlp); // 6 Decimals

        stableToDeposit = _adjustToGMXCap(stableToDeposit);

        if (stableToDeposit < 1e4) {
            return;
        }

        uint256 availableForBorrowing = stable.balanceOf(address(stableVault));

        if (availableForBorrowing == 0) {
            return;
        }

        if (availableForBorrowing < stableToDeposit) {
            stableToDeposit = availableForBorrowing;
        }

        uint256 stableToBorrow = stableToDeposit - stable.balanceOf(address(this));

        stableVault.borrow(stableToBorrow);
        emit BorrowStable(stableToBorrow);

        stableDebt = stableDebt + stableToBorrow;

        address stableAsset = address(stable);
        IERC20(stableAsset).approve(routerV2.glpManager(), stableToDeposit);
        uint256 glpMinted = routerV2.mintAndStakeGlp(stableAsset, stableToDeposit, 0, 0);

        emit Leverage(_glpAmount, glpMinted);
    }

    function _deleverage(uint256 _excessGlp) private returns (uint256) {
        uint256 stablesReceived = routerV2.unstakeAndRedeemGlp(address(stable), _excessGlp, 0, address(this));

        uint256 currentStableDebt = stableDebt;

        if (stablesReceived <= currentStableDebt) {
            _repayStable(stablesReceived);
        } else {
            _repayStable(currentStableDebt);
        }

        return stablesReceived;
    }

    function _adjustToGMXCap(uint256 _stableAmount) private view returns (uint256) {
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 mintAmount = _buyGlpStableSimulation(_stableAmount);

        uint256 currentUsdgAmount = vault.usdgAmounts(usdc);

        uint256 nextAmount = currentUsdgAmount + mintAmount;
        uint256 maxUsdgAmount = vault.maxUsdgAmounts(usdc);

        if (nextAmount > maxUsdgAmount) {
            (uint256 requiredStables,) = _getRequiredStableAmount(maxUsdgAmount - currentUsdgAmount);
            return requiredStables;
        } else {
            return _stableAmount;
        }
    }

    function _getGMXCapDifference() private view returns (uint256) {
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 currentUsdgAmount = vault.usdgAmounts(usdc);

        uint256 maxUsdgAmount = vault.maxUsdgAmounts(usdc);

        return maxUsdgAmount - currentUsdgAmount;
    }

    function _buyGlpStableSimulation(uint256 _stableAmount) private view returns (uint256) {
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 aumInUsdg = manager.getAumInUsdg(true);

        uint256 usdcPrice = vault.getMinPrice(usdc); // 30 decimals

        uint256 usdgAmount = _stableAmount.mulDiv(usdcPrice, PRECISION); // 6 decimals

        usdgAmount = usdgAmount.mulDiv(GLP_DECIMALS, USDC_DECIMALS); // 18 decimals

        uint256 retentionBasisPoints =
            vault.getFeeBasisPoints(usdc, usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), true);

        uint256 amountAfterRetention = _stableAmount.mulDiv(GMX_BASIS - retentionBasisPoints, GMX_BASIS); // 6 decimals

        uint256 mintAmount = amountAfterRetention.mulDiv(usdcPrice, PRECISION); // 6 decimals

        mintAmount = mintAmount.mulDiv(GLP_DECIMALS, USDC_DECIMALS); // 18 decimals

        return aumInUsdg == 0 ? mintAmount : mintAmount.mulDiv(glp.totalSupply(), aumInUsdg); // 18 decimals
    }

    function _buyGlpStableSimulationWhitoutRetention(uint256 _stableAmount) private view returns (uint256) {
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 aumInUsdg = manager.getAumInUsdg(true);

        uint256 usdcPrice = vault.getMinPrice(usdc); // 30 decimals

        uint256 usdgAmount = _stableAmount.mulDiv(usdcPrice, PRECISION); // 6 decimals

        usdgAmount = usdgAmount.mulDiv(GLP_DECIMALS, USDC_DECIMALS); // 18 decimals

        uint256 mintAmount = _stableAmount.mulDiv(usdcPrice, PRECISION); // 6 decimals

        mintAmount = mintAmount.mulDiv(GLP_DECIMALS, USDC_DECIMALS); // 18 decimals

        return aumInUsdg == 0 ? mintAmount : mintAmount.mulDiv(glp.totalSupply(), aumInUsdg); // 18 decimals
    }

    function _sellGlpStableSimulation(uint256 _glpAmount) private view returns (uint256, uint256) {
        IGlpManager manager = glpManager;
        IGMXVault vault = IGMXVault(manager.vault());

        address usdc = address(stable);

        uint256 usdgAmount = _glpAmount.mulDiv(manager.getAumInUsdg(false), glp.totalSupply());

        uint256 redemptionAmount = usdgAmount.mulDiv(PRECISION, vault.getMaxPrice(usdc));

        redemptionAmount = redemptionAmount.mulDiv(USDC_DECIMALS, GLP_DECIMALS); // 6 decimals

        uint256 retentionBasisPoints =
            _getGMXBasisRetention(usdc, usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), false);

        return (redemptionAmount.mulDiv(GMX_BASIS - retentionBasisPoints, GMX_BASIS), retentionBasisPoints);
    }

    function _glpMintIncentive(uint256 _glpAmount) private view returns (uint256) {
        uint256 amountToMint = _glpAmount.mulDiv(leverageConfig.target - BASIS_POINTS, BASIS_POINTS); // 18 Decimals
        (uint256 stablesNeeded, uint256 gmxIncentive) = _getRequiredStableAmount(amountToMint + 2);
        uint256 incentiveInStables = stablesNeeded.mulDiv(gmxIncentive, GMX_BASIS);
        return _buyGlpStableSimulationWhitoutRetention(incentiveInStables); // retention in glp
    }

    function _glpRedeemRetention(uint256 _glpAmount) private view returns (uint256) {
        uint256 amountToRedeem = _glpAmount.mulDiv(leverageConfig.target - BASIS_POINTS, BASIS_POINTS); //18
        (, uint256 gmxRetention) = _sellGlpStableSimulation(amountToRedeem + 2);
        uint256 retentionInGlp = amountToRedeem.mulDiv(gmxRetention, GMX_BASIS);
        return retentionInGlp;
    }

    function _getGMXBasisRetention(
        address _token,
        uint256 _usdgDelta,
        uint256 _retentionBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) private view returns (uint256) {
        IGMXVault vault = IGMXVault(glpManager.vault());

        if (!vault.hasDynamicFees()) return _retentionBasisPoints;

        uint256 initialAmount = _increment ? vault.usdgAmounts(_token) : vault.usdgAmounts(_token) - _usdgDelta;

        uint256 nextAmount = initialAmount + _usdgDelta;
        if (!_increment) {
            nextAmount = _usdgDelta > initialAmount ? 0 : initialAmount - _usdgDelta;
        }

        uint256 targetAmount = vault.getTargetUsdgAmount(_token);
        if (targetAmount == 0) return _retentionBasisPoints;

        uint256 initialDiff = initialAmount > targetAmount ? initialAmount - targetAmount : targetAmount - initialAmount;
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount - targetAmount : targetAmount - nextAmount;

        // action improves relative asset balance
        if (nextDiff < initialDiff) {
            uint256 rebateBps = _taxBasisPoints.mulDiv(initialDiff, targetAmount);
            return rebateBps > _retentionBasisPoints ? 0 : _retentionBasisPoints - rebateBps;
        }

        uint256 averageDiff = (initialDiff + nextDiff) / 2;
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = _taxBasisPoints.mulDiv(averageDiff, targetAmount);
        return _retentionBasisPoints + taxBps;
    }
}
