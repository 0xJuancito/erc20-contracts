// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2023 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.10;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Governable} from "src/common/Governable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OperableKeepable} from "src/common/OperableKeepable.sol";
import {IGmxRewardRouter} from "src/interfaces/IGmxRewardRouter.sol";
import {JonesGlpVaultRouter} from "src/glp/JonesGlpVaultRouter.sol";
import {IJonesGlpCompoundRewards} from "src/interfaces/IJonesGlpCompoundRewards.sol";
import {IJonesGlpRewardTracker} from "src/interfaces/IJonesGlpRewardTracker.sol";
import {IIncentiveReceiver} from "src/interfaces/IIncentiveReceiver.sol";
import {GlpJonesRewards} from "src/glp/rewards/GlpJonesRewards.sol";

contract JonesGlpCompoundRewards is IJonesGlpCompoundRewards, ERC20, OperableKeepable, ReentrancyGuard {
    using Math for uint256;

    uint256 public constant BASIS_POINTS = 1e12;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant glp = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
    IGmxRewardRouter public gmxRouter = IGmxRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);

    IERC20 public asset;
    IERC20Metadata public vaultToken;

    uint256 public stableRetentionPercentage;
    uint256 public glpRetentionPercentage;

    uint256 public totalAssets; // total assets;
    uint256 public totalAssetsDeposits; // total assets deposits;

    mapping(address => uint256) public receiptBalance; // assets deposits

    JonesGlpVaultRouter public router;
    IJonesGlpRewardTracker public tracker;
    IIncentiveReceiver public incentiveReceiver;
    GlpJonesRewards public jonesRewards;

    constructor(
        uint256 _stableRetentionPercentage,
        uint256 _glpRetentionPercentage,
        IIncentiveReceiver _incentiveReceiver,
        IJonesGlpRewardTracker _tracker,
        GlpJonesRewards _jonesRewards,
        IERC20 _asset,
        IERC20Metadata _vaultToken,
        string memory _name,
        string memory _symbol
    ) Governable(msg.sender) ERC20(_name, _symbol) ReentrancyGuard() {
        if (_stableRetentionPercentage > BASIS_POINTS) {
            revert RetentionPercentageOutOfRange();
        }
        if (_glpRetentionPercentage > BASIS_POINTS) {
            revert RetentionPercentageOutOfRange();
        }

        stableRetentionPercentage = _stableRetentionPercentage;
        glpRetentionPercentage = _glpRetentionPercentage;
        incentiveReceiver = _incentiveReceiver;
        jonesRewards = _jonesRewards;

        asset = _asset;
        vaultToken = _vaultToken;

        tracker = _tracker;
    }

    // ============================= Keeper Functions ================================ //

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function compound() external onlyOperatorOrKeeper {
        _compound();
    }

    // ============================= Operable Functions ================================ //

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function deposit(uint256 _assets, address _receiver) external nonReentrant onlyOperator returns (uint256) {
        uint256 shares = previewDeposit(_assets);
        _deposit(_receiver, _assets, shares);

        return shares;
    }

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function redeem(uint256 _shares, address _receiver) external nonReentrant onlyOperator returns (uint256) {
        uint256 assets = previewRedeem(_shares);
        _withdraw(_receiver, assets, _shares);

        return assets;
    }

    // ============================= Public Functions ================================ //

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @inheritdoc IJonesGlpCompoundRewards
     */
    function totalAssetsToDeposits(address recipient, uint256 assets) public view returns (uint256) {
        uint256 totalRecipientAssets = _convertToAssets(balanceOf(recipient), Math.Rounding.Down);
        return assets.mulDiv(receiptBalance[recipient], totalRecipientAssets, Math.Rounding.Down);
    }

    // ============================= Governor Functions ================================ //

    /**
     * @notice Transfer all Glp managed by this contract to an address
     * @param _to Address to transfer funds
     */
    function emergencyGlpWithdraw(address _to) external onlyGovernor {
        _compound();
        router.redeemGlp(tracker.stakedAmount(address(this)), false);
        asset.transfer(_to, asset.balanceOf(address(this)));
    }

    /**
     * @notice Transfer all Stable assets managed by this contract to an address
     * @param _to Address to transfer funds
     */
    function emergencyStableWithdraw(address _to) external onlyGovernor {
        _compound();
        router.stableWithdrawalSignal(tracker.stakedAmount(address(this)), false);
        asset.transfer(_to, asset.balanceOf(address(this)));
    }

    /**
     * @notice Set new router contract
     * @param _router New router contract
     */
    function setRouter(JonesGlpVaultRouter _router) external onlyGovernor {
        router = _router;
    }

    /**
     * @notice Set new retention received
     * @param _incentiveReceiver New retention received
     */
    function setIncentiveReceiver(IIncentiveReceiver _incentiveReceiver) external onlyGovernor {
        incentiveReceiver = _incentiveReceiver;
    }

    /**
     * @notice Set new reward tracker contract
     * @param _tracker New reward tracker contract
     */
    function setRewardTracker(IJonesGlpRewardTracker _tracker) external onlyGovernor {
        tracker = _tracker;
    }

    /**
     * @notice Set new asset
     * @param _asset New asset
     */
    function setAsset(IERC20Metadata _asset) external onlyGovernor {
        asset = _asset;
    }

    /**
     * @notice Set new vault token
     * @param _vaultToken New vault token contract
     */
    function setVaultToken(IERC20Metadata _vaultToken) external onlyGovernor {
        vaultToken = _vaultToken;
    }

    /**
     * @notice Set new gmx router contract
     * @param _gmxRouter New gmx router contract
     */
    function setGmxRouter(IGmxRewardRouter _gmxRouter) external onlyGovernor {
        gmxRouter = _gmxRouter;
    }

    /**
     * @notice Set new retentions
     * @param _stableRetentionPercentage New stable retention
     * @param _glpRetentionPercentage New glp retention
     */
    function setNewRetentions(uint256 _stableRetentionPercentage, uint256 _glpRetentionPercentage)
        external
        onlyGovernor
    {
        if (_stableRetentionPercentage > BASIS_POINTS) {
            revert RetentionPercentageOutOfRange();
        }
        if (_glpRetentionPercentage > BASIS_POINTS) {
            revert RetentionPercentageOutOfRange();
        }

        stableRetentionPercentage = _stableRetentionPercentage;
        glpRetentionPercentage = _glpRetentionPercentage;
    }

    /**
     * @notice Set Jones Rewards Contract
     * @param _jonesRewards Contract that manage Jones Rewards
     */
    function setJonesRewards(GlpJonesRewards _jonesRewards) external onlyGovernor {
        jonesRewards = _jonesRewards;
    }

    // ============================= Private Functions ================================ //

    function _deposit(address receiver, uint256 assets, uint256 shares) private {
        vaultToken.transferFrom(msg.sender, address(this), assets);

        receiptBalance[receiver] = receiptBalance[receiver] + assets;

        vaultToken.approve(address(tracker), assets);
        tracker.stake(address(this), assets);

        totalAssetsDeposits = totalAssetsDeposits + assets;
        totalAssets = tracker.stakedAmount(address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _withdraw(address receiver, uint256 assets, uint256 shares) private {
        uint256 depositAssets = totalAssetsToDeposits(receiver, assets);

        _burn(receiver, shares);

        receiptBalance[receiver] = receiptBalance[receiver] - depositAssets;

        totalAssetsDeposits = totalAssetsDeposits - depositAssets;

        tracker.withdraw(address(this), assets);

        vaultToken.approve(address(tracker), assets);
        tracker.stake(receiver, assets);

        totalAssets = tracker.stakedAmount(address(this));

        emit Withdraw(msg.sender, receiver, assets, shares);
    }

    function _compound() private {
        (uint256 stableRewards, uint256 glpRewards,) = router.claimRewards();
        if (glpRewards > 0) {
            uint256 retention = _retention(glpRewards, glpRetentionPercentage);
            if (retention > 0) {
                IERC20(weth).approve(address(incentiveReceiver), retention);
                incentiveReceiver.deposit(weth, retention);
                glpRewards = glpRewards - retention;
            }

            IERC20(weth).approve(gmxRouter.glpManager(), glpRewards);
            uint256 glpAmount = gmxRouter.mintAndStakeGlp(weth, glpRewards, 0, 0);
            glpRewards = glpAmount;

            IERC20(glp).approve(address(router), glpRewards);
            router.depositGlp(glpRewards, address(this), false);
            totalAssets = tracker.stakedAmount(address(this));

            // Information needed to calculate compounding rewards per Vault
            emit Compound(glpRewards, totalAssets, retention);
        }
        if (stableRewards > 0) {
            uint256 retention = _retention(stableRewards, stableRetentionPercentage);
            if (retention > 0) {
                IERC20(usdc).approve(address(incentiveReceiver), retention);
                incentiveReceiver.deposit(usdc, retention);
                stableRewards = stableRewards - retention;
            }

            IERC20(usdc).approve(address(router), stableRewards);
            router.depositStable(stableRewards, false, address(this));
            totalAssets = tracker.stakedAmount(address(this));

            // Information needed to calculate compounding rewards per Vault
            emit Compound(stableRewards, totalAssets, retention);
        }
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) private view returns (uint256 shares) {
        uint256 supply = totalSupply();

        return (assets == 0 || supply == 0)
            ? assets.mulDiv(10 ** decimals(), 10 ** vaultToken.decimals(), rounding)
            : assets.mulDiv(supply, totalAssets, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) private view returns (uint256 assets) {
        uint256 supply = totalSupply();
        return (supply == 0)
            ? shares.mulDiv(10 ** vaultToken.decimals(), 10 ** decimals(), rounding)
            : shares.mulDiv(totalAssets, supply, rounding);
    }

    function _retention(uint256 _rewards, uint256 _retentionPercentage) private pure returns (uint256) {
        return (_rewards * _retentionPercentage) / BASIS_POINTS;
    }

    function internalTransfer(address from, address to, uint256 amount) private {
        uint256 assets = previewRedeem(amount);
        uint256 depositAssets = totalAssetsToDeposits(from, assets);
        receiptBalance[from] = receiptBalance[from] - depositAssets;
        receiptBalance[to] = receiptBalance[to] + depositAssets;
        if (address(asset) == usdc) {
            jonesRewards.getReward(from);
            jonesRewards.withdraw(from, depositAssets);
            jonesRewards.stake(to, depositAssets);
        }
    }

    /// ============================= ERC20 Functions ================================ //

    function name() public view override returns (string memory) {
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        return super.symbol();
    }

    function decimals() public view override returns (uint8) {
        return super.decimals();
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        internalTransfer(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return super.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        return super.approve(spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        internalTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }
}
