// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Pausable} from "../common/Pausable.sol";
import {WhitelistController} from "../common/WhitelistController.sol";
import {JonesGlpVault} from "./vaults/JonesGlpVault.sol";
import {JonesGlpStableVault} from "./vaults/JonesGlpStableVault.sol";
import {Governable} from "../common/Governable.sol";
import {GlpJonesRewards} from "./rewards/GlpJonesRewards.sol";
import {IGmxRewardRouter} from "../interfaces/IGmxRewardRouter.sol";
import {IWhitelistController} from "../interfaces/IWhitelistController.sol";
import {IJonesGlpLeverageStrategy} from "../interfaces/IJonesGlpLeverageStrategy.sol";
import {IIncentiveReceiver} from "../interfaces/IIncentiveReceiver.sol";
import {IJonesGlpRewardTracker} from "../interfaces/IJonesGlpRewardTracker.sol";
import {GlpAdapter} from "../adapters/GlpAdapter.sol";
import {IJonesGlpCompoundRewards} from "../interfaces/IJonesGlpCompoundRewards.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Errors} from "src/interfaces/Errors.sol";

contract JonesGlpVaultRouter is Governable, Pausable, ReentrancyGuard {
    bool public initialized;

    struct WithdrawalSignal {
        uint256 targetEpoch;
        uint256 commitedShares;
        bool redeemed;
        bool compound;
    }

    IGmxRewardRouter private constant router = IGmxRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
    address private constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    JonesGlpVault private glpVault;
    JonesGlpStableVault private glpStableVault;
    IJonesGlpLeverageStrategy public strategy;
    GlpJonesRewards private jonesRewards;
    IJonesGlpRewardTracker public glpRewardTracker;
    IJonesGlpRewardTracker public stableRewardTracker;
    IJonesGlpCompoundRewards private stableCompoundRewards;
    IJonesGlpCompoundRewards private glpCompoundRewards;
    IWhitelistController private whitelistController;
    IIncentiveReceiver private incentiveReceiver;
    GlpAdapter private adapter;

    IERC20 private glp;
    IERC20 private stable;

    // vault asset -> reward tracker
    mapping(address => IJonesGlpRewardTracker) public rewardTrackers;
    // vault asset -> reward compounder
    mapping(address => IJonesGlpCompoundRewards) public rewardCompounder;

    mapping(address => mapping(uint256 => WithdrawalSignal)) public userSignal;

    uint256 private constant BASIS_POINTS = 1e12;
    uint256 private constant EPOCH_DURATION = 1 days;
    uint256 public EXIT_COOLDOWN;
    uint256 public pendingWithdrawals;

    constructor(
        JonesGlpVault _glpVault,
        JonesGlpStableVault _glpStableVault,
        IJonesGlpLeverageStrategy _strategy,
        GlpJonesRewards _jonesRewards,
        IJonesGlpRewardTracker _glpRewardTracker,
        IJonesGlpRewardTracker _stableRewardTracker,
        IJonesGlpCompoundRewards _glpCompoundRewards,
        IJonesGlpCompoundRewards _stableCompoundRewards,
        IWhitelistController _whitelistController,
        IIncentiveReceiver _incentiveReceiver
    ) Governable(msg.sender) {
        glpVault = _glpVault;
        glpStableVault = _glpStableVault;
        strategy = _strategy;
        jonesRewards = _jonesRewards;
        glpRewardTracker = _glpRewardTracker;
        stableRewardTracker = _stableRewardTracker;
        glpCompoundRewards = _glpCompoundRewards;
        stableCompoundRewards = _stableCompoundRewards;
        whitelistController = _whitelistController;

        incentiveReceiver = _incentiveReceiver;
    }

    function initialize(address _glp, address _stable, address _adapter) external onlyGovernor {
        if (initialized) {
            revert Errors.AlreadyInitialized();
        }

        rewardTrackers[_glp] = glpRewardTracker;
        rewardTrackers[_stable] = stableRewardTracker;
        rewardCompounder[_glp] = glpCompoundRewards;
        rewardCompounder[_stable] = stableCompoundRewards;

        glp = IERC20(_glp);
        stable = IERC20(_stable);
        adapter = GlpAdapter(_adapter);
        initialized = true;
    }

    // ============================= Whitelisted functions ================================ //

    /**
     * @notice The Adapter contract can deposit GLP to the system on behalf of the _sender
     * @param _assets Amount of assets deposited
     * @param _sender address of who is deposit the assets
     * @param _compound optional compounding rewards
     * @return Amount of shares jGLP minted
     */
    function depositGlp(uint256 _assets, address _sender, bool _compound) external whenNotPaused returns (uint256) {
        _onlyInternalContract(); //can only be adapter or compounder

        bytes32 role = whitelistController.getUserRole(_sender);
        IWhitelistController.RoleInfo memory info = whitelistController.getRoleInfo(role);

        IJonesGlpLeverageStrategy _strategy = strategy;
        JonesGlpVault _glpVault = glpVault;

        uint256 assetsUsdValue = _strategy.getStableGlpValue(_assets);
        uint256 underlyingUsdValue = _strategy.getStableGlpValue(_strategy.getUnderlyingGlp());
        uint256 maxTvlGlp = getMaxCapGlp();

        if ((assetsUsdValue + underlyingUsdValue) * BASIS_POINTS > maxTvlGlp && !info.jGLP_BYPASS_CAP) {
            revert Errors.MaxGlpTvlReached();
        }

        if (_compound) {
            glpCompoundRewards.compound();
        }

        (uint256 compoundShares, uint256 vaultShares) = _deposit(_glpVault, _sender, _assets, _compound);

        _strategy.onGlpDeposit(_assets);

        if (_compound) {
            emit DepositGlp(_sender, _assets, compoundShares, _compound);
            return compoundShares;
        }

        emit DepositGlp(_sender, _assets, vaultShares, _compound);

        return vaultShares;
    }

    /**
     * @notice Users & Whitelist contract can redeem GLP from the system
     * @param _shares Amount of jGLP deposited to redeem GLP
     * @param _compound flag if the rewards are compounding
     * @return Amount of GLP remdeemed
     */
    function redeemGlp(uint256 _shares, bool _compound)
        external
        whenNotEmergencyPaused
        nonReentrant
        returns (uint256)
    {
        _onlyEOA();

        if (_compound) {
            glpCompoundRewards.compound();
            _shares = _unCompoundGlp(_shares, msg.sender);
        }

        glpRewardTracker.withdraw(msg.sender, _shares);
        JonesGlpVault _glpVault = glpVault;

        uint256 glpAmount = _glpVault.previewRedeem(_shares);

        _glpVault.burn(address(this), _shares);

        //We can't send glpAmount - retention here because it'd mess our rebalance
        glpAmount = strategy.onGlpRedeem(glpAmount);

        if (glpAmount > 0) {
            glpAmount = _distributeGlp(glpAmount, msg.sender, _compound);
        }

        return glpAmount;
    }

    /**
     * @notice User & Whitelist contract can redeem GLP using any asset of GLP basket from the system
     * @param _shares Amount of jGLP deposited to redeem GLP
     * @param _compound flag if the rewards are compounding
     * @param _token address of asset token
     * @param _user address of the user that will receive the assets
     * @param _native flag if the user will receive raw ETH
     * @return Amount of assets redeemed
     */
    function redeemGlpAdapter(uint256 _shares, bool _compound, address _token, address _user, bool _native)
        external
        whenNotEmergencyPaused
        nonReentrant
        returns (uint256)
    {
        if (msg.sender != address(adapter)) {
            revert Errors.OnlyAdapter();
        }

        if (_compound) {
            glpCompoundRewards.compound();
            _shares = _unCompoundGlp(_shares, _user);
        }
        glpRewardTracker.withdraw(_user, _shares);
        JonesGlpVault _glpVault = glpVault;

        uint256 glpAmount = _glpVault.previewRedeem(_shares);

        _glpVault.burn(address(this), _shares);

        //We can't send glpAmount - retention here because it'd mess our rebalance
        glpAmount = strategy.onGlpRedeem(glpAmount);

        if (glpAmount > 0) {
            glpAmount = _distributeGlpAdapter(glpAmount, _user, _token, _native, _compound);
        }

        return glpAmount;
    }

    /**
     * @notice adapter & compounder can deposit Stable assets to the system
     * @param _assets Amount of Stables deposited
     * @param _compound optional compounding rewards
     * @return Amount of shares jUSDC minted
     */
    function depositStable(uint256 _assets, bool _compound, address _user) external whenNotPaused returns (uint256) {
        _onlyInternalContract(); //can only be adapter or compounder

        if (_compound) {
            stableCompoundRewards.compound();
        }

        (uint256 shares, uint256 track) = _deposit(glpStableVault, _user, _assets, _compound);

        if (_user != address(rewardCompounder[address(stable)])) {
            jonesRewards.stake(_user, track);
        }

        strategy.onStableDeposit();

        emit DepositStables(_user, _assets, shares, _compound);

        return shares;
    }

    /**
     * @notice Users can signal a stable redeem or redeem directly if user has the role to do it.
     * @dev The Jones & Stable rewards stop here
     * @param _shares Amount of shares jUSDC to redeem
     * @param _compound flag if the rewards are compounding
     * @return Epoch when will be possible the redeem or the amount of stables received in case user has special role
     */
    function stableWithdrawalSignal(uint256 _shares, bool _compound)
        external
        whenNotEmergencyPaused
        returns (uint256)
    {
        _onlyEOA();

        bytes32 userRole = whitelistController.getUserRole(msg.sender);
        IWhitelistController.RoleInfo memory info = whitelistController.getRoleInfo(userRole);

        uint256 targetEpoch = currentEpoch() + EXIT_COOLDOWN;
        WithdrawalSignal storage userWithdrawalSignal = userSignal[msg.sender][targetEpoch];

        if (userWithdrawalSignal.commitedShares > 0) {
            revert Errors.WithdrawalSignalAlreadyDone();
        }

        if (_compound) {
            stableCompoundRewards.compound();
            uint256 assets = stableCompoundRewards.previewRedeem(_shares);
            uint256 assetDeposited = stableCompoundRewards.totalAssetsToDeposits(msg.sender, assets);
            jonesRewards.getReward(msg.sender);
            jonesRewards.withdraw(msg.sender, assetDeposited);
            _shares = _unCompoundStables(_shares);
        } else {
            jonesRewards.getReward(msg.sender);
            jonesRewards.withdraw(msg.sender, _shares);
        }

        rewardTrackers[address(stable)].withdraw(msg.sender, _shares);

        if (info.jUSDC_BYPASS_TIME) {
            return _redeemDirectly(_shares, info.jUSDC_RETENTION, _compound);
        }

        userWithdrawalSignal.targetEpoch = targetEpoch;
        userWithdrawalSignal.commitedShares = _shares;
        userWithdrawalSignal.compound = _compound;

        pendingWithdrawals = pendingWithdrawals + glpStableVault.previewRedeem(_shares);

        emit StableWithdrawalSignal(msg.sender, _shares, targetEpoch, _compound);

        return targetEpoch;
    }

    function _redeemDirectly(uint256 _shares, uint256 _retention, bool _compound) private returns (uint256) {
        uint256 stableAmount = glpStableVault.previewRedeem(_shares);
        uint256 stablesFromVault = _borrowStables(stableAmount);
        uint256 gmxIncentive;

        // Only redeem from strategy if there is not enough on the vault
        if (stablesFromVault < stableAmount) {
            uint256 difference = stableAmount - stablesFromVault;
            gmxIncentive = (difference * strategy.getRedeemStableGMXIncentive(difference) * 1e8) / BASIS_POINTS;
            strategy.onStableRedeem(difference, difference - gmxIncentive);
        }

        uint256 remainderStables = stableAmount - gmxIncentive;

        IERC20 stableToken = stable;

        if (stableToken.balanceOf(address(this)) < remainderStables) {
            revert Errors.NotEnoughStables();
        }

        glpStableVault.burn(address(this), _shares);

        uint256 retention = ((stableAmount * _retention) / BASIS_POINTS);

        uint256 realRetention = gmxIncentive < retention ? retention - gmxIncentive : 0;

        uint256 amountAfterRetention = remainderStables - realRetention;

        if (amountAfterRetention > 0) {
            stableToken.transfer(msg.sender, amountAfterRetention);
        }

        if (realRetention > 0) {
            stableToken.approve(address(stableRewardTracker), realRetention);
            stableRewardTracker.depositRewards(realRetention);
        }

        // Information needed to calculate stable retentions
        emit RedeemStable(msg.sender, amountAfterRetention, retention, realRetention, _compound);

        return amountAfterRetention;
    }

    /**
     * @notice Users can cancel the signal to stable redeem
     * @param _epoch Target epoch
     * @param _compound true if the rewards should be compound
     */
    function cancelStableWithdrawalSignal(uint256 _epoch, bool _compound) external {
        WithdrawalSignal memory userWithdrawalSignal = userSignal[msg.sender][_epoch];

        if (userWithdrawalSignal.redeemed) {
            revert Errors.WithdrawalAlreadyCompleted();
        }

        uint256 snapshotCommitedShares = userWithdrawalSignal.commitedShares;

        if (snapshotCommitedShares == 0) {
            return;
        }

        userWithdrawalSignal.commitedShares = 0;
        userWithdrawalSignal.targetEpoch = 0;
        userWithdrawalSignal.compound = false;

        IJonesGlpRewardTracker tracker = stableRewardTracker;

        jonesRewards.stake(msg.sender, snapshotCommitedShares);

        if (_compound) {
            stableCompoundRewards.compound();
            IJonesGlpCompoundRewards compounder = rewardCompounder[address(stable)];
            IERC20(address(glpStableVault)).approve(address(compounder), snapshotCommitedShares);
            compounder.deposit(snapshotCommitedShares, msg.sender);
        } else {
            IERC20(address(glpStableVault)).approve(address(tracker), snapshotCommitedShares);
            tracker.stake(msg.sender, snapshotCommitedShares);
        }

        // Update struct storage
        userSignal[msg.sender][_epoch] = userWithdrawalSignal;

        pendingWithdrawals = pendingWithdrawals - glpStableVault.previewRedeem(snapshotCommitedShares);

        emit CancelStableWithdrawalSignal(msg.sender, snapshotCommitedShares, _compound);
    }

    /**
     * @notice Users can redeem stable assets from the system
     * @param _epoch Target epoch
     * @return Amount of stables reeemed
     */
    function redeemStable(uint256 _epoch) external whenNotEmergencyPaused returns (uint256) {
        bytes32 userRole = whitelistController.getUserRole(msg.sender);
        IWhitelistController.RoleInfo memory info = whitelistController.getRoleInfo(userRole);

        WithdrawalSignal memory userWithdrawalSignal = userSignal[msg.sender][_epoch];

        if (currentEpoch() < userWithdrawalSignal.targetEpoch || userWithdrawalSignal.targetEpoch == 0) {
            revert Errors.NotRightEpoch();
        }

        if (userWithdrawalSignal.redeemed) {
            revert Errors.WithdrawalAlreadyCompleted();
        }

        if (userWithdrawalSignal.commitedShares == 0) {
            revert Errors.WithdrawalWithNoShares();
        }

        uint256 stableAmount = glpStableVault.previewRedeem(userWithdrawalSignal.commitedShares);

        uint256 stablesFromVault = _borrowStables(stableAmount);

        uint256 gmxIncentive;

        // Only redeem from strategy if there is not enough on the vault
        if (stablesFromVault < stableAmount) {
            uint256 difference = stableAmount - stablesFromVault;
            gmxIncentive = (difference * strategy.getRedeemStableGMXIncentive(difference) * 1e8) / BASIS_POINTS;
            strategy.onStableRedeem(difference, difference - gmxIncentive);
        }

        uint256 remainderStables = stableAmount - gmxIncentive;

        IERC20 stableToken = stable;

        if (stableToken.balanceOf(address(this)) < remainderStables) {
            revert Errors.NotEnoughStables();
        }

        glpStableVault.burn(address(this), userWithdrawalSignal.commitedShares);

        WithdrawalSignal storage withdrawalSingal = userSignal[msg.sender][_epoch];
        withdrawalSingal.redeemed = true;

        uint256 retention = ((stableAmount * info.jUSDC_RETENTION) / BASIS_POINTS);

        uint256 realRetention = gmxIncentive < retention ? retention - gmxIncentive : 0;

        uint256 amountAfterRetention = remainderStables - realRetention;

        if (amountAfterRetention > 0) {
            stableToken.transfer(msg.sender, amountAfterRetention);
        }

        if (realRetention > 0) {
            stableToken.approve(address(stableRewardTracker), realRetention);
            stableRewardTracker.depositRewards(realRetention);
        }

        pendingWithdrawals = pendingWithdrawals - stableAmount;

        // Information needed to calculate stable retention
        emit RedeemStable(msg.sender, amountAfterRetention, retention, realRetention, userWithdrawalSignal.compound);

        return amountAfterRetention;
    }

    /**
     * @notice User & Whitelist contract can claim their rewards
     * @return Stable rewards comming from Stable deposits
     * @return ETH rewards comming from GLP deposits
     * @return Jones rewards comming from jones emission
     */
    function claimRewards() external returns (uint256, uint256, uint256) {
        strategy.claimGlpRewards();

        uint256 stableRewards = stableRewardTracker.claim(msg.sender);

        stable.transfer(msg.sender, stableRewards);

        uint256 glpRewards = glpRewardTracker.claim(msg.sender);

        IERC20(weth).transfer(msg.sender, glpRewards);

        uint256 _jonesRewards = jonesRewards.getReward(msg.sender);

        emit ClaimRewards(msg.sender, stableRewards, glpRewards, _jonesRewards);

        return (stableRewards, glpRewards, _jonesRewards);
    }

    /**
     * @notice User Compound rewards
     * @param _stableDeposits Amount of stable shares to compound
     * @param _glpDeposits Amount of glp shares to compound
     * @return Amount of USDC shares
     * @return Amount of GLP shares
     */
    function compoundRewards(uint256 _stableDeposits, uint256 _glpDeposits) external returns (uint256, uint256) {
        return (compoundStableRewards(_stableDeposits), compoundGlpRewards(_glpDeposits));
    }

    /**
     * @notice User UnCompound rewards
     * @param _stableDeposits Amount of stable shares to uncompound
     * @param _glpDeposits Amount of glp shares to uncompound
     * @return Amount of USDC shares
     * @return Amount of GLP shares
     */
    function unCompoundRewards(uint256 _stableDeposits, uint256 _glpDeposits, address _user)
        external
        returns (uint256, uint256)
    {
        return (unCompoundStableRewards(_stableDeposits), unCompoundGlpRewards(_glpDeposits, _user));
    }

    /**
     * @notice User Compound GLP rewards
     * @param _shares Amount of glp shares to compound
     * @return Amount of jGLP shares
     */
    function compoundGlpRewards(uint256 _shares) public returns (uint256) {
        glpCompoundRewards.compound();
        // claim rewards & mint GLP
        strategy.claimGlpRewards();
        uint256 rewards = glpRewardTracker.claim(msg.sender); // WETH

        uint256 rewardShares;
        if (rewards != 0) {
            IERC20(weth).approve(router.glpManager(), rewards);
            uint256 glpAmount = router.mintAndStakeGlp(weth, rewards, 0, 0);

            // vault deposit GLP to get jGLP
            glp.approve(address(glpVault), glpAmount);
            rewardShares = glpVault.deposit(glpAmount, address(this));
        }

        // withdraw jGlp
        uint256 currentShares = glpRewardTracker.withdraw(msg.sender, _shares);

        // Stake in Rewards Tracker & Deposit into compounder
        IJonesGlpCompoundRewards compounder = rewardCompounder[address(glp)];
        uint256 totalShares = currentShares + rewardShares;
        IERC20(address(glpVault)).approve(address(compounder), totalShares);
        uint256 shares = compounder.deposit(totalShares, msg.sender);

        emit CompoundGlp(msg.sender, totalShares);

        return shares;
    }

    /**
     * @notice User UnCompound GLP rewards
     * @param _shares Amount of glp shares to uncompound
     * @return Amount of GLP shares
     */
    function unCompoundGlpRewards(uint256 _shares, address _user) public returns (uint256) {
        glpCompoundRewards.compound();
        return _unCompoundGlp(_shares, _user);
    }

    /**
     * @notice User Compound Stable rewards
     * @param _shares Amount of stable shares to compound
     * @return Amount of jUSDC shares
     */
    function compoundStableRewards(uint256 _shares) public returns (uint256) {
        stableCompoundRewards.compound();
        // claim rewards & deposit USDC
        strategy.claimGlpRewards();
        uint256 rewards = stableRewardTracker.claim(msg.sender); // USDC

        // vault deposit USDC to get jUSDC
        uint256 rewardShares;
        if (rewards > 0) {
            stable.approve(address(glpStableVault), rewards);
            rewardShares = glpStableVault.deposit(rewards, address(this));
        }

        // withdraw jUSDC
        uint256 currentShares = stableRewardTracker.withdraw(msg.sender, _shares);

        // Stake in Rewards Tracker & Deposit into compounder
        IJonesGlpCompoundRewards compounder = rewardCompounder[address(stable)];
        uint256 totalShares = currentShares + rewardShares;
        IERC20(address(glpStableVault)).approve(address(compounder), totalShares);
        uint256 shares = compounder.deposit(totalShares, msg.sender);

        emit CompoundStables(msg.sender, totalShares);

        return shares;
    }

    /**
     * @notice User UnCompound rewards
     * @param _shares Amount of stable shares to uncompound
     * @return Amount of USDC shares
     */
    function unCompoundStableRewards(uint256 _shares) public returns (uint256) {
        stableCompoundRewards.compound();
        IJonesGlpCompoundRewards compounder = rewardCompounder[address(stable)];

        uint256 assets = compounder.previewRedeem(_shares);
        uint256 assetsDeposited = compounder.totalAssetsToDeposits(msg.sender, assets);

        uint256 difference = assets - assetsDeposited;
        if (difference > 0) {
            jonesRewards.stake(msg.sender, difference);
        }

        return _unCompoundStables(_shares);
    }

    // ============================= External functions ================================ //
    /**
     * @notice Return user withdrawal signal
     * @param user address of user
     * @param epoch address of user
     * @return Targe Epoch
     * @return Commited shares
     * @return Redeem boolean
     */
    function withdrawSignal(address user, uint256 epoch) external view returns (uint256, uint256, bool, bool) {
        WithdrawalSignal memory userWithdrawalSignal = userSignal[user][epoch];
        return (
            userWithdrawalSignal.targetEpoch,
            userWithdrawalSignal.commitedShares,
            userWithdrawalSignal.redeemed,
            userWithdrawalSignal.compound
        );
    }

    /**
     * @notice Return the max amount of GLP that can be deposit in order to be alaign with the target leverage
     * @return GLP Cap
     */
    function getMaxCapGlp() public view returns (uint256) {
        return (glpStableVault.tvl() * BASIS_POINTS) / (strategy.getTargetLeverage() - BASIS_POINTS); // 18 decimals
    }

    // ============================= Governor functions ================================ //
    /**
     * @notice Set exit cooldown length in days
     * @param _days amount of days a user needs to wait to withdraw his stables
     */
    function setExitCooldown(uint256 _days) external onlyGovernor {
        EXIT_COOLDOWN = _days * EPOCH_DURATION;
    }

    /**
     * @notice Set Jones Rewards Contract
     * @param _jonesRewards Contract that manage Jones Rewards
     */
    function setJonesRewards(GlpJonesRewards _jonesRewards) external onlyGovernor {
        address previousAddress = address(jonesRewards);
        jonesRewards = _jonesRewards;
        emit SetJonesRewards(previousAddress, address(_jonesRewards));
    }

    /**
     * @notice Set Leverage Strategy Contract
     * @param _leverageStrategy Leverage Strategy address
     */
    function setLeverageStrategy(address _leverageStrategy) external onlyGovernor {
        address previousAddress = address(strategy);
        strategy = IJonesGlpLeverageStrategy(_leverageStrategy);
        emit SetJonesLeverageStrategy(previousAddress, _leverageStrategy);
    }

    /**
     * @notice Set Stable Compound Contract
     * @param _stableCompoundRewards Stable Compound address
     */
    function setStableCompoundRewards(address _stableCompoundRewards) external onlyGovernor {
        address oldStableCompoundRewards = address(stableCompoundRewards);
        stableCompoundRewards = IJonesGlpCompoundRewards(_stableCompoundRewards);
        rewardCompounder[address(stable)] = stableCompoundRewards;
        emit UpdateStableCompoundRewards(oldStableCompoundRewards, _stableCompoundRewards);
    }

    /**
     * @notice Set GLP Compound Contract
     * @param _glpCompoundRewards GLP Compound address
     */
    function setGlpCompoundRewards(address _glpCompoundRewards) external onlyGovernor {
        address oldGlpCompoundRewards = address(glpCompoundRewards);
        glpCompoundRewards = IJonesGlpCompoundRewards(_glpCompoundRewards);
        rewardCompounder[address(glp)] = glpCompoundRewards;
        emit UpdateGlpCompoundRewards(oldGlpCompoundRewards, _glpCompoundRewards);
    }

    /**
     * @notice Set Stable Tracker Contract
     * @param _stableRewardTracker Stable Tracker address
     */
    function setStableRewardTracker(address _stableRewardTracker) external onlyGovernor {
        address oldStableRewardTracker = address(stableRewardTracker);
        stableRewardTracker = IJonesGlpRewardTracker(_stableRewardTracker);
        rewardTrackers[address(stable)] = stableRewardTracker;
        emit UpdateStableRewardTracker(oldStableRewardTracker, _stableRewardTracker);
    }

    /**
     * @notice Set GLP Tracker Contract
     * @param _glpRewardTracker GLP Tracker address
     */
    function setGlpRewardTracker(address _glpRewardTracker) external onlyGovernor {
        address oldGlpRewardTracker = address(glpRewardTracker);
        glpRewardTracker = IJonesGlpRewardTracker(_glpRewardTracker);
        rewardTrackers[address(glp)] = glpRewardTracker;
        emit UpdateGlpRewardTracker(oldGlpRewardTracker, _glpRewardTracker);
    }

    /**
     * @notice Set a new incentive Receiver address
     * @param _newIncentiveReceiver Incentive Receiver Address
     */
    function setIncentiveReceiver(address _newIncentiveReceiver) external onlyGovernor {
        if (_newIncentiveReceiver == address(0)) {
            revert Errors.AddressCannotBeZeroAddress();
        }

        address oldIncentiveReceiver = address(incentiveReceiver);
        incentiveReceiver = IIncentiveReceiver(_newIncentiveReceiver);

        emit UpdateIncentiveReceiver(oldIncentiveReceiver, _newIncentiveReceiver);
    }

    /**
     * @notice Set GLP Adapter Contract
     * @param _adapter GLP Adapter address
     */
    function setGlpAdapter(address _adapter) external onlyGovernor {
        if (_adapter == address(0)) {
            revert Errors.AddressCannotBeZeroAddress();
        }

        address oldAdapter = address(adapter);
        adapter = GlpAdapter(_adapter);

        emit UpdateAdapter(oldAdapter, _adapter);
    }

    // ============================= Private functions ================================ //

    function _deposit(IERC4626 _vault, address _caller, uint256 _assets, bool compound)
        private
        returns (uint256, uint256)
    {
        IERC20 asset = IERC20(_vault.asset());
        address adapterAddress = address(adapter);
        IJonesGlpRewardTracker tracker = rewardTrackers[address(asset)];

        if (msg.sender == adapterAddress) {
            asset.transferFrom(adapterAddress, address(this), _assets);
        } else {
            asset.transferFrom(_caller, address(this), _assets);
        }

        uint256 vaultShares = _vaultDeposit(_vault, _assets);

        uint256 compoundShares;

        if (compound) {
            IJonesGlpCompoundRewards compounder = rewardCompounder[address(asset)];
            IERC20(address(_vault)).approve(address(compounder), vaultShares);
            compoundShares = compounder.deposit(vaultShares, _caller);
        } else {
            IERC20(address(_vault)).approve(address(tracker), vaultShares);
            tracker.stake(_caller, vaultShares);
        }

        return (compoundShares, vaultShares);
    }

    function _distributeGlp(uint256 _amount, address _dest, bool _compound) private returns (uint256) {
        uint256 retention = _chargeIncentive(_amount, _dest);
        uint256 wethAmount;

        if (retention > 0) {
            wethAmount = router.unstakeAndRedeemGlp(weth, retention, 0, address(this));
            uint256 jonesRetention = (wethAmount * 2) / 3;
            IERC20(weth).approve(address(incentiveReceiver), jonesRetention);
            incentiveReceiver.deposit(weth, jonesRetention);
            IERC20(weth).approve(address(glpRewardTracker), wethAmount - jonesRetention);

            glpRewardTracker.depositRewards(wethAmount - jonesRetention);
        }

        uint256 glpAfterRetention = _amount - retention;

        glp.transfer(_dest, glpAfterRetention);

        // Information needed to calculate glp retention
        emit RedeemGlp(_dest, glpAfterRetention, retention, wethAmount, _compound);

        return glpAfterRetention;
    }

    function _distributeGlpAdapter(uint256 _amount, address _dest, address _token, bool _native, bool _compound)
        private
        returns (uint256)
    {
        uint256 retention = _chargeIncentive(_amount, _dest);

        uint256 wethAmount;

        if (retention > 0) {
            wethAmount = router.unstakeAndRedeemGlp(weth, retention, 0, address(this));
            uint256 jonesRetention = (wethAmount * 2) / 3;
            IERC20(weth).approve(address(incentiveReceiver), jonesRetention);
            incentiveReceiver.deposit(weth, jonesRetention);
            IERC20(weth).approve(address(glpRewardTracker), wethAmount - jonesRetention);

            glpRewardTracker.depositRewards(wethAmount - jonesRetention);
        }

        if (_native) {
            uint256 ethAmount = router.unstakeAndRedeemGlpETH(_amount - retention, 0, payable(_dest));

            // Information needed to calculate glp retention
            emit RedeemGlpEth(_dest, _amount - retention, retention, wethAmount, ethAmount);

            return ethAmount;
        }

        uint256 assetAmount = router.unstakeAndRedeemGlp(_token, _amount - retention, 0, _dest);

        // Information needed to calculate glp retention
        emit RedeemGlpBasket(_dest, _amount - retention, retention, wethAmount, _token, _compound);

        return assetAmount;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp / EPOCH_DURATION) * EPOCH_DURATION;
    }

    function _borrowStables(uint256 _amount) private returns (uint256) {
        JonesGlpStableVault stableVault = glpStableVault;

        uint256 balance = stable.balanceOf(address(stableVault));
        if (balance == 0) {
            return 0;
        }

        uint256 amountToBorrow = balance < _amount ? balance : _amount;

        emit BorrowStables(amountToBorrow);

        return stableVault.borrow(amountToBorrow);
    }

    function _chargeIncentive(uint256 _withdrawAmount, address _sender) private returns (uint256) {
        bytes32 userRole = whitelistController.getUserRole(_sender);
        IWhitelistController.RoleInfo memory info = whitelistController.getRoleInfo(userRole);

        uint256 retention = (_withdrawAmount * info.jGLP_RETENTION) / BASIS_POINTS;

        emit RetentionCharged(retention);
        return retention;
    }

    function _unCompoundGlp(uint256 _shares, address _user) private returns (uint256) {
        IJonesGlpCompoundRewards compounder = rewardCompounder[address(glp)];

        uint256 shares = compounder.redeem(_shares, _user);

        emit unCompoundGlp(_user, _shares);

        return shares;
    }

    function _unCompoundStables(uint256 _shares) private returns (uint256) {
        IJonesGlpCompoundRewards compounder = rewardCompounder[address(stable)];

        uint256 shares = compounder.redeem(_shares, msg.sender);

        emit unCompoundStables(msg.sender, _shares);

        return shares;
    }

    function _vaultDeposit(IERC4626 _vault, uint256 _assets) private returns (uint256) {
        address asset = _vault.asset();
        address vaultAddress = address(_vault);
        uint256 vaultShares;
        if (_vault.asset() == address(glp)) {
            uint256 glpMintIncentives = strategy.glpMintIncentive(_assets);

            uint256 assetsToDeposit = _assets - glpMintIncentives;

            IERC20(asset).approve(vaultAddress, assetsToDeposit);

            vaultShares = _vault.deposit(assetsToDeposit, address(this));
            if (glpMintIncentives > 0) {
                glp.transfer(vaultAddress, glpMintIncentives);
            }

            emit VaultDeposit(vaultAddress, _assets, glpMintIncentives);
        } else {
            IERC20(asset).approve(vaultAddress, _assets);
            vaultShares = _vault.deposit(_assets, address(this));
            emit VaultDeposit(vaultAddress, _assets, 0);
        }
        return vaultShares;
    }

    function _onlyInternalContract() private view {
        if (!whitelistController.isInternalContract(msg.sender)) {
            revert Errors.CallerIsNotInternalContract();
        }
    }

    function _onlyEOA() private view {
        if (msg.sender != tx.origin && !whitelistController.isWhitelistedContract(msg.sender)) {
            revert Errors.CallerIsNotWhitelisted();
        }
    }

    function togglePause() external onlyGovernor {
        if (paused()) {
            _unpause();
            return;
        }

        _pause();
    }

    function toggleEmergencyPause() external onlyGovernor {
        if (emergencyPaused()) {
            _emergencyUnpause();
            return;
        }

        _emergencyPause();
    }

    event UpdateIncentiveReceiver(address _oldIncentiveReceiver, address _newIncentiveReceiver);
    event UpdateStableRewardTracker(address _oldStableTracker, address _newStableTracker);
    event UpdateGlpRewardTracker(address _oldGlpTracker, address _newGlpTracker);
    event UpdateStableCompoundRewards(address _oldStableCompounder, address _newStableCompounder);
    event UpdateGlpCompoundRewards(address _oldGlpeCompounder, address _newGlpCompounder);
    event UpdateWithdrawalRetention(uint256 _newRetention);
    event UpdateAdapter(address _oldAdapter, address _newAdapter);
    event UpdateGlpVault(address _oldGlpVault, address _newGlpVault);
    event UpdateStableVault(address _oldStableVault, address _newStableVault);
    event UpdateStableAddress(address _oldStableAddress, address _newStableAddress);
    event UpdateGlpAddress(address _oldGlpAddress, address _newGlpAddress);
    event DepositGlp(address indexed _to, uint256 _amount, uint256 _sharesReceived, bool _compound);
    event DepositStables(address indexed _to, uint256 _amount, uint256 _sharesReceived, bool _compound);
    event VaultDeposit(address indexed vault, uint256 _amount, uint256 _retention);
    event RedeemGlpBasket(
        address indexed _to,
        uint256 _amount,
        uint256 _retentions,
        uint256 _ethRetentions,
        address _token,
        bool _compound
    );
    event RedeemGlpEth(
        address indexed _to, uint256 _amount, uint256 _retentions, uint256 _ethRetentions, uint256 _ethAmount
    );
    event RedeemGlp(address indexed _to, uint256 _amount, uint256 _retentions, uint256 _ethRetentions, bool _compound);
    event RedeemStable(
        address indexed _to, uint256 _amount, uint256 _retentions, uint256 _realRetentions, bool _compound
    );
    event ClaimRewards(address indexed _to, uint256 _stableAmount, uint256 _wEthAmount, uint256 _amountJones);
    event CompoundGlp(address indexed _to, uint256 _amount);
    event CompoundStables(address indexed _to, uint256 _amount);
    event unCompoundGlp(address indexed _to, uint256 _amount);
    event unCompoundStables(address indexed _to, uint256 _amount);
    event SettleEpoch(uint256 _currentEpochTs, uint256 indexed _targetEpochTs);
    event StableWithdrawalSignal(
        address indexed sender, uint256 _shares, uint256 indexed _targetEpochTs, bool _compound
    );
    event CancelStableWithdrawalSignal(address indexed sender, uint256 _shares, bool _compound);
    event RetentionCharged(uint256 indexed _retentions);
    event BorrowStables(uint256 indexed _amountBorrowed);
    event SetJonesRewards(address indexed _previousAddress, address indexed _newAddress);
    event SetJonesLeverageStrategy(address indexed _previousADdress, address indexed _newAddress);
}
